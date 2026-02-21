# CLAUDE.md — NygDevAzure

This file provides guidance for AI assistants working in this repository.

## What This Repository Is

A pure Infrastructure-as-Code (IaC) repository. It provisions and manages Azure cloud infrastructure using Terraform, deployed via GitHub Actions. There is no application code here — the hosted application (Foundry VTT, a Node.js tabletop RPG platform) is installed on the VM at boot via cloud-init.

---

## Repository Structure

```
NygDevAzure/
├── .github/
│   └── workflows/
│       ├── terraform-apply.yml     # Main deploy workflow (plan → apply)
│       └── test-azure-login.yml    # OIDC login smoke test
├── terraform/
│   ├── providers.tf                # Terraform version, AzureRM provider, remote state backend
│   ├── variables.tf                # All input variables with defaults
│   ├── network.tf                  # VNet, subnet, NSG, public IP
│   ├── vm.tf                       # VM, NIC, data disk attachment, auto-shutdown
│   ├── outputs.tf                  # Exported resource IDs and private IP
│   └── cloud-init.yml              # VM bootstrap script (cloud-config format)
├── README.md
└── CLAUDE.md                       # This file
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| IaC | Terraform >= 1.0, AzureRM provider ~> 4.0 |
| Cloud | Microsoft Azure, region: `norwayeast` |
| CI/CD | GitHub Actions with OIDC authentication |
| VM OS | Ubuntu (latest daily minimal image from Canonical) |
| App stack on VM | Caddy (reverse proxy) + Foundry VTT (Node.js) |

---

## Azure Architecture

```
Azure (norwayeast)
├── Resource Group: rg-nygdev-network
│   ├── Virtual Network: nygdev-vnet  (10.0.0.0/24)
│   │   └── Subnet: rpg-snet          (10.0.0.0/29)
│   ├── NSG: nygdev-nsg
│   │   ├── Rule WebHosting (priority 100): TCP 80,443 from Any
│   │   └── Rule L69        (priority 101): Any 22,30000,30001 from home_ip only
│   └── Public IP: rpg-pip (Static Standard, FQDN: rpg.norwayeast.cloudapp.azure.com)
│
├── Resource Group: rg-rpg
│   ├── VM: rpg-vm (Standard_B1s, Ubuntu minimal)
│   │   ├── SSH key auth only, no password, no VM agent
│   │   ├── OS disk: 30 GB StandardSSD
│   │   └── Auto-shutdown: 23:00 W. Europe Standard Time (Oslo/CET)
│   └── NIC: rpg-vm-nic (dynamic private IP, attached to rpg-pip)
│
└── Resource Group: FOUNDRY (pre-existing, not managed by this repo)
    └── Managed Disk: foundrydata (persistent data disk, attached as LUN 0)
```

### VM Filesystem Layout (after cloud-init)

```
/foundry/               ← persistent data disk mount point
├── foundrydata/        ← Foundry VTT data directory
├── foundryvtt/         ← Foundry VTT application files
├── caddy/
│   ├── Caddyfile       ← symlinked from /etc/caddy/Caddyfile
│   ├── config/         ← Caddy config (XDG_CONFIG_HOME)
│   └── data/           ← Caddy data/certs (XDG_DATA_HOME)
└── home/               ← srv_foundry user home
```

---

## Terraform Variables

Defined in `terraform/variables.tf`. Three are **required at runtime** (no default or sensitive):

| Variable | Default | Sensitive | Source |
|---|---|---|---|
| `location` | `norwayeast` | No | Hardcoded default |
| `home_ip` | — | **Yes** | Azure Key Vault (`nygdev` vault, secret `HomeIP`) |
| `ssh_public_key` | — | **Yes** | Azure SSH Keys resource (`FreeServices/NygDev`) |
| `vm_name` | `rpg-vm` | No | Hardcoded default |
| `vm_size` | `Standard_B1s` | No | Hardcoded default |
| `admin_username` | `admthenyg` | No | Hardcoded default |
| `network_resource_group` | `rg-nygdev-network` | No | Hardcoded default |
| `vm_resource_group` | `rg-rpg` | No | Hardcoded default |
| `ubuntu_offer` | `ubuntu-25_10-daily` | No | Resolved at pipeline runtime |

**Never commit `home_ip` or `ssh_public_key` values.** They are injected only via the GitHub Actions workflow.

---

## Terraform State

Remote backend in Azure Blob Storage, authenticated via Entra ID (no storage account keys):

| Setting | Value |
|---|---|
| Resource Group | `Automation` |
| Storage Account | `nygdevtfstate` |
| Container | `tfstate` |
| Key | `azure-infrastructure.tfstate` |

The `use_azuread_auth = true` setting means the identity running `terraform init` must have Storage Blob Data Contributor (or equivalent) on the container.

---

## CI/CD Workflow

### Authentication

GitHub Actions authenticates to Azure via **OIDC / Workload Identity Federation** — no long-lived secrets. The workflow requires three repository secrets in the `NygDevAzure` environment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The `ARM_USE_CLI: "true"` env var tells the AzureRM Terraform provider to delegate auth to the Azure CLI session established by the `azure/login@v2` action.

### terraform-apply.yml (main deploy workflow)

Triggered manually (`workflow_dispatch`). Two sequential jobs:

**Job 1 — plan:**
1. Azure CLI login (OIDC)
2. Install latest Terraform (fetched dynamically from HashiCorp API)
3. Retrieve `HomeIP` from Azure Key Vault → mask it in logs → set `HOME_IP` env var
4. Retrieve SSH public key from Azure SSH Keys resource → set `SSH_PUBLIC_KEY` env var
5. Resolve the latest Ubuntu daily offer name from Canonical's image list → set `UBUNTU_OFFER` env var
6. `terraform init` (working-directory: `terraform/`)
7. `terraform plan -var=... -out=tfplan`
8. Upload `tfplan` artifact (retained 1 day)

**Job 2 — apply** (depends on plan job):
1. Azure CLI login (OIDC)
2. Install latest Terraform
3. Download `tfplan` artifact
4. `terraform init`
5. `terraform apply -auto-approve tfplan`

### test-azure-login.yml

Simple smoke test that verifies OIDC is working: runs `az account show` and `az group list`. Run this if authentication problems arise.

---

## Naming Conventions

This repo follows **Cloud Adoption Framework (CAF) lowercase** naming:

| Resource type | Pattern | Example |
|---|---|---|
| Resource Group | `rg-<project>-<purpose>` | `rg-nygdev-network`, `rg-rpg` |
| Virtual Network | `<project>-vnet` | `nygdev-vnet` |
| Subnet | `<purpose>-snet` | `rpg-snet` |
| NSG | `<project>-nsg` | `nygdev-nsg` |
| Public IP | `<purpose>-pip` | `rpg-pip` |
| VM | `<purpose>-vm` | `rpg-vm` |
| NIC | `<vm-name>-nic` | `rpg-vm-nic` |
| OS Disk | `<vm-name>-osdisk` | `rpg-vm-osdisk` |

Use this convention when adding new resources.

---

## Terraform File Conventions

- One file per resource type: `network.tf`, `vm.tf`, `outputs.tf`
- Variables live exclusively in `variables.tf`; do not declare variables inline in other files
- Provider and backend config live in `providers.tf`
- Reference variables via `var.<name>`, not by hard-coding values
- Reference resource attributes via the resource address (e.g., `azurerm_resource_group.network.name`)
- Mark sensitive variables with `sensitive = true` in `variables.tf`
- Use `data` sources for pre-existing resources not managed by this repo (see `foundrydata` disk in `vm.tf`)

---

## Cloud-Init Conventions (`terraform/cloud-init.yml`)

- Format: `#cloud-config` (cloud-config YAML, not a shell script)
- The file is passed to the VM as `custom_data` via `base64encode(file(...))` in `vm.tf`
- Disk setup uses the Azure udev path `/dev/disk/azure/scsi1/lun0` — do not use `/dev/sd*` paths which are unstable
- `overwrite: false` on disk/fs setup protects the persistent data disk on re-deploy
- Service user is `srv_foundry` (system account, no login shell for interactive use)
- Caddy config/data directories are stored on the persistent disk under `/foundry/caddy/` and configured via systemd drop-in overrides

---

## Security Posture — Key Rules

1. **Never open additional NSG ports to `*` (Any source).** SSH and app ports (22, 30000, 30001) must remain restricted to `var.home_ip`.
2. **Never enable `provision_vm_agent` or `allow_extension_operations`.** These are intentionally disabled to minimize attack surface.
3. **Never add password authentication** to the VM. `disable_password_authentication = true` must remain.
4. **Never commit secret values** (`home_ip`, SSH keys, credentials). All secrets are injected at pipeline runtime.
5. The auto-shutdown schedule is a cost control measure — do not remove it.

---

## Local Development (Without CI)

To run Terraform locally, you need:

1. Azure CLI authenticated with an identity that has:
   - Contributor on resource groups `rg-nygdev-network` and `rg-rpg`
   - Key Vault Secrets User on the `nygdev` vault
   - Storage Blob Data Contributor on the `nygdevtfstate` container
2. Provide required variables manually:

```bash
cd terraform
terraform init
terraform plan \
  -var="home_ip=<YOUR_IP>" \
  -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)" \
  -var="ubuntu_offer=ubuntu-25_10-daily"
```

There is no `.tfvars` file committed to the repo — do not create one with real values.

---

## Adding New Infrastructure

When adding a new Azure resource:

1. Create or extend the appropriate `.tf` file (group by resource type)
2. Follow CAF naming conventions
3. If the resource needs a new input, add it to `variables.tf` with a `description` and sensible `default`
4. Add relevant outputs to `outputs.tf`
5. If the resource is pre-existing and unmanaged by this repo, use a `data` source
6. Validate: `terraform validate` and `terraform plan` before committing

---

## What This Repo Does NOT Contain

- Application source code (Foundry VTT binary is installed on the VM)
- Caddyfile (lives on the persistent `/foundry/caddy/` disk, managed manually)
- Any language-specific package files (no `package.json`, `requirements.txt`, etc.)
- Secrets or credentials of any kind
- Terraform modules (all resources are root-level)
