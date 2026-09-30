# Combine AzureRM and AzAPI pricing resources behind one module output.
output "defender_plan_ids" {
  description = "Resource IDs of the enabled Defender plans."
  value = merge(
    { for name, plan in azurerm_security_center_subscription_pricing.plan : name => plan.id },
    try({ AI = azapi_resource.ai_plan[0].id }, {}),
    try({ Api = azapi_resource.api_plan[0].id }, {})
  )
}

output "defender_plan_names" {
  description = "Names of the Defender plans configured by this module."
  value       = sort(keys(var.defender_plans))
}

output "security_benchmark_assignment_id" {
  description = "Microsoft Cloud Security Benchmark assignment ID, when enabled."
  value       = try(azurerm_subscription_policy_assignment.security_benchmark[0].id, null)
}