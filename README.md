# Microsoft Defender for Cloud

This folder contains a reusable Terraform module and an environment-aware root configuration for the Defender plans selected in the security team's screenshots.

See [DEPLOYMENT-INSTRUCTION-SET.md](DEPLOYMENT-INSTRUCTION-SET.md) for the complete operational deployment, promotion, verification, troubleshooting, and rollback procedure.

## Test Scope

| Portal plan | Terraform pricing name | Selection |
|---|---|---|
| Servers | `VirtualMachines` / P1 | On |
| App Service | `AppServices` | On |
| Databases | `SqlServers`, `SqlServerVirtualMachines`, `OpenSourceRelationalDatabases`, `CosmosDbs` | On (4/4) |
| Storage | `StorageAccounts` / DefenderForStorageV2 | On, malware scanning and sensitive-data discovery enabled |
| Containers | `Containers` | On, all plan extensions enabled |
| AI Services | `AI` | On, all plan extensions enabled |
| Key Vault | `KeyVaults` / PerKeyVault | On |
| Resource Manager | `Arm` / PerSubscription | On |
| APIs | `Api` / P1 | On |

The `Standard` plans are billable. Confirm the target subscription and cost approval before applying.

## Additional Configuration

The root configures Defender only at subscription scope. It does not create or associate a Log Analytics workspace, install workspace solutions, or configure continuous export. It also configures the Microsoft Cloud Security Benchmark, Defender for Endpoint integration, Microsoft Defender Vulnerability Management, and a security contact.

Servers P1 does not support agentless VM scanning, so `enable_agentless_vm_scanning` must remain `false`. When downgrading an existing P2 subscription, disable its `AgentlessVmScanning` pricing extension before applying P1.

Declarative imports are optional because customer subscriptions may be greenfield or brownfield. Keep `adopt_existing_resources = false` when the target Defender resources do not exist. Set it to `true` when Defender pricing, MDE, MDVM, or agentless scanner settings already exist and must be adopted into the selected environment's Terraform state. Terraform 1.7 or newer is required for these import blocks.

Azure can initialize `Microsoft.Security` resources even in subscriptions with no workloads. Run a plan with the greenfield default first. If Azure reports that a target resource already exists, enable `adopt_existing_resources`, generate a new saved plan, and review each import before applying.

| Scenario | `adopt_existing_resources` | Expected behavior |
|---|---:|---|
| New subscription with no target Defender resources | `false` | No imports; Terraform creates and configures enabled resources |
| Defender previously enabled manually, by policy, or by another deployment | `true` | Existing enabled plans and settings are imported into this environment's state |
| Unsure whether Azure initialized Defender resources | Start with `false` | Plan first; switch to `true` only if Azure reports existing target resources |

Brownfield imports cover configured AzureRM pricing plans, Defender for AI and APIs pricing, the MDE `WDATP` setting, the MDVM `AzureServersSetting`, and the optional agentless VM scanner. Imports do not create duplicate resources; they establish Terraform state ownership for the existing Azure resource IDs. Use a new state key for each environment and never import the same Azure resource into multiple active Terraform states.

## Environment Configuration

Environment values are separated from the reusable Terraform code:

- `environments/dev.tfvars`
- `environments/staging.tfvars`
- `environments/prod.tfvars`

Replace all angle-bracket placeholders before planning staging or production. Each environment must use a separate backend key to prevent state collisions. Copy the matching file from `environments/backend/*.backend.hcl.example`, remove the `.example` suffix, and enter the approved state storage details.

## Deployment

Select the Azure subscription that matches the tfvars file, initialize its backend, and pass the environment file to every plan or apply command. The example below uses `dev`; replace `dev` consistently with `staging` or `prod` when promoting.

```powershell
az login
az account set --subscription '<subscription-id>'
terraform init -reconfigure -backend-config='environments/backend/dev.backend.hcl'
terraform fmt -check -recursive
terraform validate
terraform plan -var-file='environments/dev.tfvars' -out='dev.tfplan'
terraform apply 'dev.tfplan'
```

Always review the saved plan and require the environment's approval gate before apply. Never apply a plan generated for a different environment or subscription.

### Dev Lab State

The dev lab was applied successfully using local state at `.terraform/environment-test.tfstate`. After creating `environments/backend/dev.backend.hcl`, migrate that state once with the following command. Do not use `-reconfigure` for this first dev backend initialization because that would leave the deployed resources outside the remote state.

```powershell
terraform init -migrate-state -backend-config='environments/backend/dev.backend.hcl'
```

The lab identity cannot create subscription policy assignments, so `dev.tfvars` disables the Microsoft Cloud Security Benchmark assignment. Staging and production retain the secure default and require `Microsoft.Authorization/policyAssignments/write`.

The deployment identity needs permissions for subscription pricing and settings plus policy assignments when enabled. Register `Microsoft.Security` and `Microsoft.PolicyInsights` in the target subscription before deployment.

Reference: [Deploy Microsoft Defender for Cloud via Terraform](https://techcommunity.microsoft.com/blog/microsoftdefendercloudblog/deploy-microsoft-defender-for-cloud-via-terraform/3563710)