# Combine AzureRM and AzAPI pricing resources behind one module output.
output "defender_plan_ids" {
  description = "Resource IDs of the enabled Defender plans."
  value = merge(
    { for name, plan in azurerm_security_center_subscription_pricing.plan : name => plan.id },
    try({ AI = azapi_resource.ai_plan[0].id }, {})
  )
}

output "security_benchmark_assignment_id" {
  description = "Microsoft Cloud Security Benchmark assignment ID, when enabled."
  value       = try(azurerm_subscription_policy_assignment.security_benchmark[0].id, null)
}