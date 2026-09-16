# AzureRM manages every approved pricing resource except Defender for AI.
locals {
  azurerm_defender_plans = {
    for name, plan in var.defender_plans : name => plan if name != "AI"
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
  subplan       = each.value.subplan

  # Preserve provider/portal-created extensions such as agentless discovery settings.
  lifecycle {
    ignore_changes = [extension]
  }
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
    }
  }
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

# Associate the protected subscription with the selected Log Analytics workspace.
resource "azurerm_security_center_workspace" "defender" {
  scope        = var.subscription_resource_id
  workspace_id = var.log_analytics_workspace_id
}

# Install solutions through the LAW provider so central workspaces are supported.
resource "azurerm_log_analytics_solution" "security" {
  count    = var.enable_workspace_solutions ? 1 : 0
  provider = azurerm.log_analytics

  solution_name         = "Security"
  location              = var.log_analytics_location
  resource_group_name   = var.log_analytics_resource_group_name
  workspace_resource_id = var.log_analytics_workspace_id
  workspace_name        = var.log_analytics_workspace_name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Security"
  }
}

resource "azurerm_log_analytics_solution" "security_center_free" {
  count    = var.enable_workspace_solutions ? 1 : 0
  provider = azurerm.log_analytics

  solution_name         = "SecurityCenterFree"
  location              = var.log_analytics_location
  resource_group_name   = var.log_analytics_resource_group_name
  workspace_resource_id = var.log_analytics_workspace_id
  workspace_name        = var.log_analytics_workspace_name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityCenterFree"
  }
}

# Export actionable alerts and posture data to the selected workspace.
resource "azurerm_security_center_automation" "continuous_export" {
  count = var.enable_continuous_export ? 1 : 0

  name                = "ExportToWorkspace"
  location            = var.location
  resource_group_name = var.resource_group_name

  action {
    type        = "loganalytics"
    resource_id = var.log_analytics_workspace_id
  }

  source {
    event_source = "Alerts"

    rule_set {
      rule {
        property_path  = "Severity"
        operator       = "Equals"
        expected_value = "High"
        property_type  = "String"
      }

      rule {
        property_path  = "Severity"
        operator       = "Equals"
        expected_value = "Medium"
        property_type  = "String"
      }
    }
  }

  source {
    event_source = "SecureScores"
  }

  source {
    event_source = "SecureScoreControls"
  }

  scopes = [var.subscription_resource_id]
}