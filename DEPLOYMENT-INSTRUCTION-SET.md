# Microsoft Defender for Cloud Deployment Instruction Set

## 1. Purpose

This document defines the controlled process for deploying Microsoft Defender for Cloud through Terraform to the `dev`, `staging`, and `prod` environments.

The configuration enables the Defender plans approved by the security team at subscription scope and adopts subscription-level Defender resources that Azure creates automatically. It does not create or associate a Log Analytics workspace.

## 2. Deployment Scope

The following plans are configured at `Standard` tier and can generate Azure charges:

| Defender plan | Terraform pricing name | Subplan |
|---|---|---|
| Servers | `VirtualMachines` | `P1` |
| App Service | `AppServices` | Default |
| SQL databases | `SqlServers` | Default |
| SQL servers on machines | `SqlServerVirtualMachines` | Default |
| Open-source relational databases | `OpenSourceRelationalDatabases` | Default |
| Cosmos DB | `CosmosDbs` | Default |
| Storage | `StorageAccounts` | `DefenderForStorageV2` |
| Containers | `Containers` | Default |
| AI Services | `AI` | Default |
| Key Vault | `KeyVaults` | `PerKeyVault` |
| Resource Manager | `Arm` | `PerSubscription` |
| APIs | `Api` | `P1` |

Storage malware scanning and sensitive-data discovery are enabled. All supported Containers and AI Services extensions are enabled. Agentless VM scanning is disabled because it requires Servers P2.

## 3. Prerequisites

- Terraform 1.7 or newer.
- Azure CLI authenticated to the target tenant.
- An approved Azure subscription for the selected environment.
- Cost approval for all `Standard` Defender plans.
- A remote Azure Storage backend with one state key per environment.
- Required resource providers registered:
  - `Microsoft.Security`
  - `Microsoft.PolicyInsights`
- Deployment identity permissions for Microsoft.Security settings and Defender pricing.
- `Microsoft.Authorization/policyAssignments/write` for staging and production when the Microsoft Cloud Security Benchmark assignment is enabled.
- Required organizational tags identified before deployment.

## 4. Environment Files

Use the matching variable file for every command:

| Environment | Variables | Backend template | State key |
|---|---|---|---|
| Development | `environments/dev.tfvars` | `environments/backend/dev.backend.hcl.example` | `defender/dev.tfstate` |
| Staging | `environments/staging.tfvars` | `environments/backend/staging.backend.hcl.example` | `defender/staging.tfstate` |
| Production | `environments/prod.tfvars` | `environments/backend/prod.backend.hcl.example` | `defender/prod.tfstate` |

Before deployment:

1. Replace every angle-bracket placeholder in the selected tfvars file.
2. Confirm the subscription ID and security contact.
3. Copy the selected backend template and remove `.example` from its name.
4. Enter the approved backend resource group, storage account, and container.
5. Confirm the backend key is unique to the environment.
6. Do not commit populated backend files when they contain environment-sensitive values.

## 5. Pre-Deployment Checks

Set the environment name once in PowerShell:

```powershell
$environment = 'staging' # dev, staging, or prod
$tfvars = "environments/$environment.tfvars"
$backend = "environments/backend/$environment.backend.hcl"
```

Authenticate and select the subscription declared in the tfvars file:

```powershell
az login
az account set --subscription '<target-subscription-id>'
az account show --query '{name:name,id:id,tenantId:tenantId,state:state}' --output table
```

Verify provider registration:

```powershell
az provider show --namespace Microsoft.Security --query registrationState --output tsv
az provider show --namespace Microsoft.PolicyInsights --query registrationState --output tsv
az provider show --namespace Microsoft.OperationalInsights --query registrationState --output tsv
az provider show --namespace Microsoft.OperationsManagement --query registrationState --output tsv
```

Each result must be `Registered` before deployment.

## 6. Backend Initialization

For the first staging or production deployment:

```powershell
terraform init -reconfigure -backend-config=$backend
```

For subsequent deployments, run the same command when backend settings change. Never use one environment's backend with another environment's tfvars.

### Dev State Migration

The validated dev deployment currently uses local state at `.terraform/environment-test.tfstate`. Migrate it once after creating `environments/backend/dev.backend.hcl`:

```powershell
$environment = 'dev'
$backend = 'environments/backend/dev.backend.hcl'
terraform init -migrate-state -backend-config=$backend
```

Review and approve Terraform's state migration prompt. Do not use `-reconfigure` for this first dev migration because it would not copy the deployed state.

## 7. Validate and Plan

Select the import mode in the environment tfvars before planning:

| Subscription state | Setting | Result |
|---|---|---|
| Greenfield; target Defender resources do not exist | `adopt_existing_resources = false` | Import collections are empty |
| Brownfield; Defender was enabled previously | `adopt_existing_resources = true` | Existing configured plans and singleton settings are adopted into this state |
| State is unknown | Start with `false` | Plan first and switch to `true` only after an existing-resource response |

Brownfield mode imports the configured AzureRM pricing plans, AI and API pricing, MDE, MDVM, and agentless VM scanning when enabled. An import changes Terraform state ownership; it does not recreate the Azure resource. Never manage the same Defender resource from multiple Terraform states.

Before downgrading an existing Servers P2 subscription to P1, disable the `AgentlessVmScanning` extension. Azure rejects P1 while this P2-only extension remains enabled.

```powershell
terraform fmt -check -recursive
terraform validate
terraform plan -input=false -var-file=$tfvars -out="$environment.tfplan"
terraform show -no-color "$environment.tfplan"
```

Confirm all of the following before approval:

- The plan targets the expected subscription.
- There are no unexpected deletes or replacements.
- Defender for APIs uses `Standard` tier and `P1`.
- Required Defender plans use `Standard` tier.
- Servers use `P1` and standalone agentless VM scanning is disabled.
- Storage uses `DefenderForStorageV2`.
- Storage, Containers, and AI Services extensions are enabled.
- Key Vault uses `PerKeyVault`.
- Resource Manager uses `PerSubscription`.
- Resource names and tags match the selected environment.
- The security contact is correct.

Imports in the first plan are expected only when `adopt_existing_resources = true`. Review every imported address and its resulting changes. Do not remove import blocks to work around an existing-resource error.

## 8. Approval Gates

Obtain the following approvals before apply:

- Security approval for plan selection and contact details.
- FinOps or service-owner approval for billable plans.
- Platform approval for subscription, naming, tags, and backend.
- Change approval for staging and production.
- Confirmation that the saved plan has no unintended destruction.

## 9. Apply

Apply only the saved and approved plan:

```powershell
terraform apply -input=false "$environment.tfplan"
```

Do not run `terraform apply` without a saved plan in staging or production. Do not reuse a plan after changing Terraform files, tfvars, credentials, or the selected subscription.

## 10. Post-Deployment Verification

Run a fresh plan. A successful, converged deployment returns `No changes`:

```powershell
terraform plan -input=false -detailed-exitcode -var-file=$tfvars
```

Exit code `0` means no changes. Exit code `2` means Terraform detected changes. Exit code `1` means an error occurred.

Verify Defender pricing:

```powershell
az security pricing list --subscription '<target-subscription-id>' `
  --query "value[?name=='VirtualMachines' || name=='AppServices' || name=='SqlServers' || name=='SqlServerVirtualMachines' || name=='OpenSourceRelationalDatabases' || name=='CosmosDbs' || name=='StorageAccounts' || name=='Containers' || name=='AI' || name=='Api' || name=='KeyVaults' || name=='Arm'].{plan:name,tier:pricingTier,subPlan:subPlan,coverage:resourcesCoverageStatus}" `
  --output table
```

Verify the removed LAW integration is absent when migrating from an older deployment:

```powershell
az rest --method get `
  --url 'https://management.azure.com/subscriptions/<target-subscription-id>/providers/Microsoft.Security/workspaceSettings/default?api-version=2017-08-01-preview'
```

An HTTP `404 ResourceNotFound` confirms no Defender workspace association remains.

In the Azure portal:

1. Open **Microsoft Defender for Cloud**.
2. Select **Environment settings**.
3. Select the target subscription.
4. Confirm the plans match the approved plan table.
5. Confirm Defender for APIs uses P1.
6. Confirm Storage, Containers, and AI Services show fully enabled plan extensions.
7. Review recommendations and coverage after Defender finishes onboarding resources.

## 11. Promotion Process

Promote the same tested Terraform code in this order:

1. Deploy and verify `dev`.
2. Replace and review all `staging.tfvars` placeholders.
3. Plan, approve, apply, and verify `staging` using the staging backend.
4. Replace and review all `prod.tfvars` placeholders.
5. Plan, approve, apply, and verify `prod` using the production backend.

Do not copy state files between environments. Configuration is promoted; state remains isolated.

## 12. Troubleshooting

### Policy assignment authorization failure

Grant the deployment identity `Microsoft.Authorization/policyAssignments/write` at subscription scope. Dev currently sets `assign_security_benchmark = false` because the lab identity does not have this permission.

### Resource already exists

Confirm the resource is covered by `imports.tf`, set `adopt_existing_resources = true`, and generate a new saved plan so Terraform can execute the declarative imports. Verify that the selected backend belongs to this environment before adoption.

### Plan contains Defender resource destruction

Stop and review the current Azure subplan and extensions. Do not approve deletion or replacement of an imported pricing resource without security-team approval.

### Backend initialization error

Confirm the environment-specific backend file exists and that the deployment identity has Storage Blob Data Contributor access. Use `-migrate-state` when moving existing state and `-reconfigure` only when selecting backend configuration without migration.

## 13. Rollback and Removal

Do not use `terraform destroy` as the default Defender rollback. Destroying imported subscription-level pricing resources can disable protection or produce unsupported replacement behavior.

For rollback:

1. Stop the deployment and preserve the state and plan output.
2. Review the requested change with the security and FinOps teams.
3. Change affected plan tiers or feature flags explicitly in tfvars.
4. Generate and approve a new plan.
5. Apply the approved corrective plan.

## 14. Validated Dev Result

The dev lab deployment was validated in a dedicated test subscription.

- Log Analytics workspace, solutions, continuous export, workspace association, and their resource group were removed.
- Post-apply Terraform plan: `No changes`.
- All 12 approved Defender plans reported `Standard`; APIs use P1 and Servers use P1.
- Storage, Containers, and AI Services reported `FullyCovered` after extension enablement.
- MDE integration reported enabled.
- MDVM provider reported `MdeTvm`.
- Agentless VM scanning was removed because it is a Servers P2 capability.