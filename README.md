# Microsoft Defender for Cloud

This folder contains a reusable Terraform module and an environment-aware root configuration for the Defender plans selected in the security team's screenshots.

See [DEPLOYMENT-INSTRUCTION-SET.md](DEPLOYMENT-INSTRUCTION-SET.md) for the complete operational deployment, promotion, verification, troubleshooting, and rollback procedure.

## Test Scope

| Portal plan | Terraform pricing name | Selection |
|---|---|---|
| Defender CSPM | `CloudPosture` | On |
| Servers | `VirtualMachines` / P1 or P2 | On; P1 is the default |
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

The root configures Defender only at subscription scope. It does not create, import, modify, or delete a Log Analytics workspace (LAW), install workspace solutions, associate Defender with a workspace, or configure continuous export. An existing LAW may remain in the subscription; this configuration simply does not use or manage it. The root also configures the Microsoft Cloud Security Benchmark, Defender for Endpoint integration, Microsoft Defender Vulnerability Management, and a security contact.

## Choosing Defender for Servers P1 or P2

Customers can select P1 or P2 independently in each environment. P1 is the lower-cost default in this repository. P2 adds capabilities such as agentless VM scanning and should be enabled only after customer and cost approval.

| Setting | Servers P1 | Servers P2 with agentless scanning |
|---|---|---|
| `VirtualMachines.subplan` | `P1` | `P2` |
| `enable_agentless_vm_scanning` | `false` | `true` |
| `VirtualMachines.extensions.AgentlessVmScanning` | Omit | Enable |
| Typical use | Core server protection | Expanded server protection and agentless scanning |

Use this configuration for **Servers P1**:

```hcl
enable_agentless_vm_scanning = false

defender_plans = {
  VirtualMachines = {
    subplan = "P1"
  }

  # Keep the other approved plans here.
}
```

Use this configuration for **Servers P2 with agentless scanning**:

```hcl
enable_agentless_vm_scanning = true

defender_plans = {
  VirtualMachines = {
    subplan = "P2"
    extensions = {
      AgentlessVmScanning = {
        enabled = true
        additional_extension_properties = {
          ExclusionTags = "[]"
        }
      }
    }
  }

  # Keep the other approved plans here.
}
```

The root validation rejects unsupported Servers subplans and rejects agentless VM scanning unless Servers P2 is selected. The `AgentlessVmScanning` extension under the **Containers** plan is separate from the Servers feature and can remain enabled when Servers uses P1.

### Changing between P1 and P2

- **P1 to P2:** replace the P1 block with the P2 block, set `enable_agentless_vm_scanning = true`, then generate and review a new saved plan.
- **P2 to P1:** first disable the Servers pricing extension while the plan is still P2, then change tfvars to P1 and set `enable_agentless_vm_scanning = false`.

For a P2-to-P1 change, run this prerequisite against the confirmed target subscription:

```powershell
az security pricing create `
  --name VirtualMachines `
  --tier Standard `
  --subplan P2 `
  --extensions name=AgentlessVmScanning isEnabled=False `
  --subscription '<subscription-id>'
```

After Azure reports the extension as disabled, remove the Servers `AgentlessVmScanning` extension from tfvars, select P1, and run a fresh Terraform plan. Azure rejects a P1 change while the P2-only extension is enabled.

## Greenfield and Brownfield Deployments

Declarative imports are optional because customer subscriptions may be greenfield or brownfield. Keep `adopt_existing_resources = false` only when the configured Defender pricing and settings do not exist. Set it to `true` when Defender pricing, MDE, MDVM, or the optional agentless scanner setting already exists and must be adopted into the selected environment's Terraform state. Whether a LAW exists does not affect this setting: LAW resources are never imported by this configuration. Terraform 1.7 or newer is required for these import blocks.

Azure can initialize `Microsoft.Security` resources even in subscriptions with no workloads. Run a plan with the greenfield default first. If Azure reports that a target resource already exists, enable `adopt_existing_resources`, generate a new saved plan, and review each import before applying.

| Scenario | `adopt_existing_resources` | Expected behavior |
|---|---:|---|
| New subscription with no target Defender resources | `false` | No imports; Terraform creates and configures enabled resources |
| Defender previously enabled manually, by policy, or by another deployment | `true` | Existing enabled plans and settings are imported into this environment's state |
| A LAW exists, but configured Defender resources do not exist | `false` | The LAW is ignored; Defender resources are created without LAW integration |
| A LAW and configured Defender resources both exist | `true` | Defender resources are imported; the LAW remains outside this configuration |
| Unsure whether Azure initialized Defender resources | Start with `false` | Plan first; switch to `true` only if Azure reports existing target resources |

Brownfield imports cover configured AzureRM pricing plans, Defender for AI and APIs pricing, the MDE `WDATP` setting, the MDVM `AzureServersSetting`, the default security contact, and the optional agentless VM scanner. Imports do not create duplicate resources; they establish Terraform state ownership for the existing Azure resource IDs. Use a new state key for each environment and never import the same Azure resource into multiple active Terraform states.

When upgrading state created by an older LAW-enabled version, run `terraform state list` before planning. If that state owns a LAW or its resource group and they must be retained, back up the state and remove only those retained resource addresses from Terraform state before applying this version. The reviewed plan may delete the old Defender workspace association, Security solutions, and continuous export because those integrations are intentionally unsupported. Never approve deletion of a shared LAW or resource group.

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
terraform test
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

The deployment identity must have `Microsoft.Security/pricings/write` at subscription scope to enable CSPM, AI Services, APIs, and the other paid plans. It also needs permissions for Defender settings and policy assignments when enabled. Register `Microsoft.Security` and `Microsoft.PolicyInsights` in the target subscription before deployment. If the portal reports insufficient permissions or CSPM, AI, or API remains Off after apply, treat the deployment as incomplete and review the Terraform apply output and deployment identity role assignments.

Verify the selected Servers plan after apply:

```powershell
az security pricing show `
	--name VirtualMachines `
	--subscription '<subscription-id>' `
	--query '{tier:pricingTier,subPlan:subPlan,extensions:extensions[].{name:name,enabled:isEnabled}}' `
	--output json

terraform plan -input=false -detailed-exitcode -var-file='environments/dev.tfvars'
```

The Azure result must show `Standard` with the customer-selected P1 or P2 subplan. The final Terraform plan must report `No changes`.

Reference: [Deploy Microsoft Defender for Cloud via Terraform](https://techcommunity.microsoft.com/blog/microsoftdefendercloudblog/deploy-microsoft-defender-for-cloud-via-terraform/3563710)