locals {
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  existing_log_analytics_workspace_parts = var.existing_log_analytics_workspace_id == null ? [] : regex(
    "(?i)^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\\.OperationalInsights/workspaces/([^/]+)$",
    trimspace(var.existing_log_analytics_workspace_id)
  )
  log_analytics_subscription_id = var.existing_log_analytics_workspace_id == null ? var.subscription_id : local.existing_log_analytics_workspace_parts[0]
}

data "azurerm_subscription" "current" {}

data "azurerm_log_analytics_workspace" "existing" {
  count    = var.existing_log_analytics_workspace_id == null ? 0 : 1
  provider = azurerm.log_analytics

  name                = local.existing_log_analytics_workspace_parts[2]
  resource_group_name = local.existing_log_analytics_workspace_parts[1]
}

resource "azurerm_resource_group" "defender" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "defender" {
  count = var.existing_log_analytics_workspace_id == null ? 1 : 0

  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.defender.location
  resource_group_name = azurerm_resource_group.defender.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_retention_in_days
  tags                = local.tags

  lifecycle {
    precondition {
      condition     = var.log_analytics_workspace_name != null && trimspace(var.log_analytics_workspace_name) != ""
      error_message = "log_analytics_workspace_name is required when existing_log_analytics_workspace_id is null."
    }
  }
}

locals {
  log_analytics_workspace_id = var.existing_log_analytics_workspace_id == null ? (
    azurerm_log_analytics_workspace.defender[0].id
    ) : (
    data.azurerm_log_analytics_workspace.existing[0].id
  )
  log_analytics_workspace_name = var.existing_log_analytics_workspace_id == null ? (
    azurerm_log_analytics_workspace.defender[0].name
    ) : (
    data.azurerm_log_analytics_workspace.existing[0].name
  )
  log_analytics_workspace_location = var.existing_log_analytics_workspace_id == null ? (
    azurerm_log_analytics_workspace.defender[0].location
    ) : (
    data.azurerm_log_analytics_workspace.existing[0].location
  )
  log_analytics_workspace_resource_group_name = var.existing_log_analytics_workspace_id == null ? (
    azurerm_log_analytics_workspace.defender[0].resource_group_name
    ) : (
    data.azurerm_log_analytics_workspace.existing[0].resource_group_name
  )
}

module "defender_for_cloud" {
  source = "./modules/defender_for_cloud"

  providers = {
    azurerm               = azurerm
    azurerm.log_analytics = azurerm.log_analytics
  }

  subscription_resource_id          = data.azurerm_subscription.current.id
  location                          = azurerm_resource_group.defender.location
  resource_group_name               = azurerm_resource_group.defender.name
  log_analytics_workspace_id        = local.log_analytics_workspace_id
  log_analytics_workspace_name      = local.log_analytics_workspace_name
  log_analytics_location            = local.log_analytics_workspace_location
  log_analytics_resource_group_name = local.log_analytics_workspace_resource_group_name
  security_contact_email            = var.security_contact_email
  security_contact_phone            = var.security_contact_phone
  defender_plans                    = var.defender_plans
  assign_security_benchmark         = var.assign_security_benchmark
  enable_mde_integration            = var.enable_mde_integration
  enable_mdvm                       = var.enable_mdvm
  enable_agentless_vm_scanning      = var.enable_agentless_vm_scanning
  enable_continuous_export          = var.enable_continuous_export
  enable_workspace_solutions        = var.enable_workspace_solutions
}