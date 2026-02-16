# NygDev Azure Infrastructure

Terraform-managed Azure infrastructure deployed via Azure DevOps Pipelines. Provisions a Linux VM with networking resources in Norway East, designed for hosting an RPG application (e.g. Foundry VTT).

## Architecture

```
Azure (norwayeast)
├── Resource Group: NygDevNetwork
│   ├── Virtual Network    10.0.0.0/24
│   │   └── Subnet: RPG   10.0.0.0/29
│   ├── Network Security Group
│   │   ├── Allow HTTP/HTTPS from anywhere
│   │   └── Allow SSH + 30000-30001 from home IP only
│   └── Static Public IP (rpg.norwayeast.cloudapp.azure.com)
│
└── Resource Group: RPG
    └── Linux VM (Standard_B1s)
        ├── Latest Ubuntu Daily (minimal)
        ├── SSH key auth only
        ├── 30 GB StandardSSD OS disk
        └── Auto-shutdown at 23:00 CET
```

## Repository Structure

```
├── pipelines/
│   └── terraform-nygdev.yml    # Azure DevOps pipeline definition
└── terraform/
    ├── backend.tf              # Azure Storage state backend
    ├── providers.tf            # AzureRM provider ~> 4.0
    ├── variables.tf            # Input variables
    ├── network.tf              # VNet, subnet, NSG, public IP
    ├── vm.tf                   # VM, NIC, auto-shutdown schedule
    └── outputs.tf              # Resource IDs and private IP
```

## Pipeline

The Azure DevOps pipeline (`terraform-nygdev.yml`) runs on manual trigger and handles the full lifecycle:

1. **Install Terraform** — fetches the latest version at runtime
2. **Retrieve SSH public key** — pulls the key from Azure SSH Keys (`FreeServices/NygDev`)
3. **Resolve Ubuntu image** — discovers the newest `ubuntu-*-daily` offer from Canonical
4. **Terraform Init → Validate → Plan → Apply** — standard workflow with remote state

### Sensitive Variables

| Variable | Source | Description |
|---|---|---|
| `HomeIp` | Azure DevOps Variable Group (`NygDevVault`) | Home IP for NSG allowlisting |
| `sshPublicKey` | Azure SSH Keys resource | VM authentication key |
| `ubuntuOffer` | Resolved at runtime | Latest Ubuntu daily image offer |

## State Backend

Terraform state is stored remotely in Azure Blob Storage with Entra ID authentication:

| Setting | Value |
|---|---|
| Resource Group | `Automation` |
| Storage Account | `nygdevtfstate` |
| Container | `tfstate` |
| State Key | `azure-infrastructure.tfstate` |

## Security Highlights

- **SSH key-only authentication** — password auth is disabled
- **Home-IP-restricted access** — SSH and application ports locked to a single IP
- **Web ports open** — 80/443 allowed from anywhere for public hosting
- **No VM agent or extensions** — minimal attack surface
- **Auto-shutdown** — VM powers off nightly at 23:00 CET to control costs
- **Secrets handled in pipeline** — sensitive values never committed to source
