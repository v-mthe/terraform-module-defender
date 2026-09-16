# AzureRM manages every approved pricing resource except Defender for AI.
locals {
  azurerm_defender_plans = {
    for name, plan in var.defender_plans : name => plan if !contains(["AI", "Api"], name)
  }
  brownfield_subplans = var.adopt_existing_resources ? {
    for name, plan in local.azurerm_defender_plans : name => plan if plan.subplan != null
  } : {}
  plan_extensions = {
    for name, plan in var.defender_plans : name => plan if length(plan.extensions) > 0
  }
}

# Assign the benchmark only when the deployment identity has policy permissions.
resource "azurerm_subscription_policy_assignment" "security_benchmark" {
  count = var.assign_security_benchmark ? 1 : 0

  name                 = "mcsb"
  display_name         = "Microsoft Cloud Security Benchmark"
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
  subscription_id      = var.subscription_resource_id
}

resource "azurerm_security_center_subscription_pricing" "plan" {
  for_each = local.azurerm_defender_plans

  tier          = each.value.tier
  resource_type = each.key
  subplan       = var.adopt_existing_resources ? null : each.value.subplan

  # Preserve provider/portal-created extensions such as agentless discovery settings.
  lifecycle {
    ignore_changes = [extension, subplan]
  }
}

# AzureRM marks adding a subplan to an existing Free pricing singleton as a
# replacement. Patch brownfield subplans through ARM to avoid delete/recreate.
resource "azapi_update_resource" "brownfield_subplan" {
  for_each = local.brownfield_subplans

  type      = "Microsoft.Security/pricings@2024-01-01"
  name      = each.key
  parent_id = var.subscription_resource_id
  body = {
    properties = {
      pricingTier = each.value.tier
      subPlan     = each.value.subplan
    }
  }

  depends_on = [azurerm_security_center_subscription_pricing.plan]
}

# AzureRM 4.21 does not accept AI as a pricing resource type, so AzAPI manages it.
resource "azapi_resource" "ai_plan" {
  count = contains(keys(var.defender_plans), "AI") ? 1 : 0

  type      = "Microsoft.Security/pricings@2024-01-01"
  name      = "AI"
  parent_id = var.subscription_resource_id
  body = {
    properties = {
      pricingTier = var.defender_plans["AI"].tier
      extensions = [
        for name, extension in var.defender_plans["AI"].extensions : {
          name                          = name
          isEnabled                     = title(tostring(extension.enabled))
          additionalExtensionProperties = extension.additional_extension_properties
        }
      ]
    }
  }
}

# AzureRM 4.21 does not accept Api as a pricing resource type.
resource "azapi_resource" "api_plan" {
  count = contains(keys(var.defender_plans), "Api") ? 1 : 0

  type      = "Microsoft.Security/pricings@2024-01-01"
  name      = "Api"
  parent_id = var.subscription_resource_id
  body = {
    properties = {
      pricingTier = var.defender_plans["Api"].tier
      subPlan     = var.defender_plans["Api"].subplan
    }
  }
}

# Apply complete extension sets with PATCH semantics so existing pricing
# singletons are updated without AzureRM replacement behavior.
resource "azapi_update_resource" "plan_extensions" {
  for_each = local.plan_extensions

  type      = "Microsoft.Security/pricings@2024-01-01"
  name      = each.key
  parent_id = var.subscription_resource_id
  body = {
    properties = {
      pricingTier = each.value.tier
      extensions = [
        for name, extension in each.value.extensions : merge(
          {
            name      = name
            isEnabled = title(tostring(extension.enabled))
          },
          length(extension.additional_extension_properties) > 0 ? {
            additionalExtensionProperties = extension.additional_extension_properties
          } : {}
        )
      ]
    }
  }

  depends_on = [
    azapi_resource.ai_plan,
    azapi_resource.api_plan,
    azurerm_security_center_subscription_pricing.plan,
  ]
}

# Enable Microsoft Defender for Endpoint integration at subscription scope.
resource "azurerm_security_center_setting" "mde" {
  count = var.enable_mde_integration ? 1 : 0

  setting_name = "WDATP"
  enabled      = true
}

# Select MDE TVM as the vulnerability assessment provider for protected servers.
resource "azapi_resource" "mdvm" {
  count = var.enable_mdvm ? 1 : 0

  type      = "Microsoft.Security/serverVulnerabilityAssessmentsSettings@2022-01-01-preview"
  name      = "AzureServersSetting"
  parent_id = var.subscription_resource_id
  body = {
    kind = "AzureServersSetting"
    properties = {
      selectedProvider = "MdeTvm"
    }
  }
  schema_validation_enabled = false
}

# Configure the subscription-level agentless VM scanning singleton.
resource "azapi_resource" "agentless_vm_scanning" {
  count = var.enable_agentless_vm_scanning ? 1 : 0

  type      = "Microsoft.Security/vmScanners@2022-03-01-preview"
  name      = "default"
  parent_id = var.subscription_resource_id
  body = {
    properties = {
      scanningMode = "Default"
    }
  }
  schema_validation_enabled = false
}

# Route Defender alerts to the customer-owned security contact.
resource "azurerm_security_center_contact" "security" {
  name  = "default"
  email = var.security_contact_email
  phone = var.security_contact_phone

  alert_notifications = true
  alerts_to_admins    = true
}
