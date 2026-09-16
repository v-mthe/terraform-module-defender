# Declarative imports are opt-in so greenfield deployments do not assume resources exist.
locals {
  azurerm_defender_plan_imports = var.adopt_existing_resources ? {
    for name, plan in var.defender_plans : name => plan if !contains(["AI", "Api"], name)
  } : {}
  ai_plan_import  = var.adopt_existing_resources && contains(keys(var.defender_plans), "AI") ? { AI = "AI" } : {}
  api_plan_import = var.adopt_existing_resources && contains(keys(var.defender_plans), "Api") ? { Api = "Api" } : {}
  mde_import      = var.adopt_existing_resources && var.enable_mde_integration ? { WDATP = "WDATP" } : {}
  mdvm_import     = var.adopt_existing_resources && var.enable_mdvm ? { default = "AzureServersSetting" } : {}
  vm_scanner_import = var.adopt_existing_resources && var.enable_agentless_vm_scanning ? {
    default = "default"
  } : {}
}

# AzureRM-supported Defender plans use their pricing resource names as import IDs.
import {
  for_each = local.azurerm_defender_plan_imports

  to = module.defender_for_cloud.azurerm_security_center_subscription_pricing.plan[each.key]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/pricings/${each.key}"
}

# Defender for AI is imported separately because it is managed through AzAPI.
import {
  for_each = local.ai_plan_import

  to = module.defender_for_cloud.azapi_resource.ai_plan[0]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/pricings/${each.value}"
}

# Import the Microsoft Defender for Endpoint subscription setting when enabled.
import {
  for_each = local.mde_import

  to = module.defender_for_cloud.azurerm_security_center_setting.mde[0]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/settings/${each.value}"
}

# The remaining AzAPI imports adopt MDVM and agentless scanner singletons.
import {
  for_each = local.mdvm_import

  to = module.defender_for_cloud.azapi_resource.mdvm[0]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/serverVulnerabilityAssessmentsSettings/${each.value}"
}

import {
  for_each = local.vm_scanner_import

  to = module.defender_for_cloud.azapi_resource.agentless_vm_scanning[0]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/vmScanners/${each.value}?api-version=2022-03-01-preview"
}

# Defender for APIs is also managed through AzAPI.
import {
  for_each = local.api_plan_import

  to = module.defender_for_cloud.azapi_resource.api_plan[0]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/pricings/${each.value}"
}