mock_provider "azurerm" {}

mock_provider "azurerm" {
  alias = "log_analytics"
}

mock_provider "azapi" {}

run "create_log_analytics_workspace" {
  command = plan

  variables {
    subscription_id              = "00000000-0000-0000-0000-000000000000"
    environment                  = "dev"
    resource_group_name          = "rg-dev-defender-security"
    log_analytics_workspace_name = "law-defender-dev-01"
    security_contact_email       = "security@example.com"
    defender_plans = {
      AppServices = {}
    }
    assign_security_benchmark    = false
    enable_mde_integration       = false
    enable_mdvm                  = false
    enable_agentless_vm_scanning = false
    enable_continuous_export     = false
    enable_workspace_solutions   = false
  }

  override_data {
    target = data.azurerm_subscription.current
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = length(azurerm_log_analytics_workspace.defender) == 1
    error_message = "A Log Analytics workspace must be created when no existing workspace ID is supplied."
  }

  assert {
    condition     = length(local.azurerm_defender_plan_imports) == 0
    error_message = "Greenfield mode must not attempt to import enabled Defender plans."
  }
}

run "adopt_existing_defender_resources" {
  command = plan

  variables {
    subscription_id              = "00000000-0000-0000-0000-000000000000"
    environment                  = "dev"
    adopt_existing_resources     = true
    resource_group_name          = "rg-dev-defender-security"
    log_analytics_workspace_name = "law-defender-dev-01"
    security_contact_email       = "security@example.com"
    defender_plans = {
      AppServices = {}
    }
    assign_security_benchmark    = false
    enable_mde_integration       = false
    enable_mdvm                  = false
    enable_agentless_vm_scanning = false
    enable_continuous_export     = false
    enable_workspace_solutions   = false
  }

  override_data {
    target = data.azurerm_subscription.current
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  override_resource {
    target = module.defender_for_cloud.azurerm_security_center_subscription_pricing.plan["AppServices"]
  }

  assert {
    condition     = length(local.azurerm_defender_plan_imports) == 1
    error_message = "Brownfield mode must import the enabled existing Defender plan."
  }
}

run "use_existing_log_analytics_workspace" {
  command = plan

  variables {
    subscription_id                     = "00000000-0000-0000-0000-000000000000"
    environment                         = "dev"
    resource_group_name                 = "rg-dev-defender-security"
    existing_log_analytics_workspace_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-shared-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-shared-01"
    security_contact_email              = "security@example.com"
    defender_plans                      = {}
    assign_security_benchmark           = false
    enable_mde_integration              = false
    enable_mdvm                         = false
    enable_agentless_vm_scanning        = false
    enable_continuous_export            = false
    enable_workspace_solutions          = false
  }

  override_data {
    target = data.azurerm_subscription.current
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  override_data {
    target = data.azurerm_log_analytics_workspace.existing
    values = {
      id                  = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-shared-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-shared-01"
      name                = "law-shared-01"
      location            = "eastus2"
      resource_group_name = "rg-shared-monitoring"
    }
  }

  assert {
    condition     = length(azurerm_log_analytics_workspace.defender) == 0
    error_message = "No Log Analytics workspace may be created when an existing workspace ID is supplied."
  }

  assert {
    condition     = output.log_analytics_workspace_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-shared-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-shared-01"
    error_message = "The output must return the selected existing Log Analytics workspace ID."
  }
}
