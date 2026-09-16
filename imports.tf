locals {
  azurerm_defender_plan_imports = var.adopt_existing_resources ? {
    for name, plan in var.defender_plans : name => plan if name != "AI"
  } : {}
  ai_plan_import = var.adopt_existing_resources && contains(keys(var.defender_plans), "AI") ? { AI = "AI" } : {}
  mde_import     = var.adopt_existing_resources && var.enable_mde_integration ? { WDATP = "WDATP" } : {}
  mdvm_import    = var.adopt_existing_resources && var.enable_mdvm ? { default = "AzureServersSetting" } : {}
  vm_scanner_import = var.adopt_existing_resources && var.enable_agentless_vm_scanning ? {
    default = "default"
  } : {}
}

import {
  for_each = local.azurerm_defender_plan_imports

  to = module.defender_for_cloud.azurerm_security_center_subscription_pricing.plan[each.key]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/pricings/${each.key}"
}

import {
  for_each = local.ai_plan_import

  to = module.defender_for_cloud.azapi_resource.ai_plan[0]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/pricings/${each.value}"
}

import {
  for_each = local.mde_import

  to = module.defender_for_cloud.azurerm_security_center_setting.mde[0]
  id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Security/settings/${each.value}"
}

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