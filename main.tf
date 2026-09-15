locals {
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "defender" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "defender" {
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.defender.location
  resource_group_name = azurerm_resource_group.defender.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_retention_in_days
  tags                = local.tags
}

module "defender_for_cloud" {
  source = "./modules/defender_for_cloud"

  subscription_resource_id     = data.azurerm_subscription.current.id
  location                     = azurerm_resource_group.defender.location
  resource_group_name          = azurerm_resource_group.defender.name
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.defender.id
  log_analytics_workspace_name = azurerm_log_analytics_workspace.defender.name
  security_contact_email       = var.security_contact_email
  security_contact_phone       = var.security_contact_phone
  defender_plans               = var.defender_plans
  assign_security_benchmark    = var.assign_security_benchmark
  enable_mde_integration       = var.enable_mde_integration
  enable_mdvm                  = var.enable_mdvm
  enable_agentless_vm_scanning = var.enable_agentless_vm_scanning
  enable_continuous_export     = var.enable_continuous_export
  enable_workspace_solutions   = var.enable_workspace_solutions
}