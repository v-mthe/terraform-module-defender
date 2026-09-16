mock_provider "azurerm" {}

mock_provider "azapi" {}

run "configure_subscription_plans" {
  command = plan

  variables {
    subscription_id              = "00000000-0000-0000-0000-000000000000"
    environment                  = "dev"
    security_contact_email       = "security@example.com"
    assign_security_benchmark    = false
    enable_mde_integration       = false
    enable_mdvm                  = false
    enable_agentless_vm_scanning = false
    defender_plans = {
      VirtualMachines = {
        subplan = "P1"
      }
      StorageAccounts = {
        subplan = "DefenderForStorageV2"
        extensions = {
          OnUploadMalwareScanning = { enabled = true }
          SensitiveDataDiscovery  = { enabled = true }
        }
      }
      Api = {
        subplan = "P1"
      }
    }
  }

  override_data {
    target = data.azurerm_subscription.current
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = var.defender_plans["Api"].tier == "Standard" && var.defender_plans["Api"].subplan == "P1"
    error_message = "Defender for APIs must use Standard tier with the requested P1 subplan."
  }

  assert {
    condition     = alltrue([for extension in values(var.defender_plans["StorageAccounts"].extensions) : extension.enabled])
    error_message = "All declared Storage extensions must be enabled."
  }
}

run "adopt_existing_subscription_plans" {
  command = plan

  variables {
    subscription_id              = "00000000-0000-0000-0000-000000000000"
    environment                  = "dev"
    adopt_existing_resources     = true
    security_contact_email       = "security@example.com"
    assign_security_benchmark    = false
    enable_mde_integration       = false
    enable_mdvm                  = false
    enable_agentless_vm_scanning = false
    defender_plans = {
      AppServices = {}
      Api = {
        subplan = "P1"
      }
    }
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

  override_resource {
    target = module.defender_for_cloud.azapi_resource.api_plan[0]
  }

  assert {
    condition     = length(local.azurerm_defender_plan_imports) == 1 && length(local.api_plan_import) == 1
    error_message = "Brownfield mode must import both AzureRM and API pricing resources."
  }
}

run "reject_api_without_paid_subplan" {
  command = plan

  variables {
    subscription_id              = "00000000-0000-0000-0000-000000000000"
    environment                  = "dev"
    security_contact_email       = "security@example.com"
    assign_security_benchmark    = false
    enable_mde_integration       = false
    enable_mdvm                  = false
    enable_agentless_vm_scanning = false
    defender_plans = {
      Api = {}
    }
  }

  override_data {
    target = data.azurerm_subscription.current
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  expect_failures = [var.defender_plans]
}