output "defender_plan_ids" {
  description = "Resource IDs of the enabled Defender plans."
  value       = module.defender_for_cloud.defender_plan_ids
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Defender Log Analytics workspace."
  value       = local.log_analytics_workspace_id
}

output "security_benchmark_assignment_id" {
  description = "Microsoft Cloud Security Benchmark assignment ID, when enabled."
  value       = module.defender_for_cloud.security_benchmark_assignment_id
}