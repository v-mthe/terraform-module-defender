# Root outputs expose resources commonly consumed by pipelines and verification steps.
output "defender_plan_ids" {
  description = "Resource IDs of the enabled Defender plans."
  value       = module.defender_for_cloud.defender_plan_ids
}

output "security_benchmark_assignment_id" {
  description = "Microsoft Cloud Security Benchmark assignment ID, when enabled."
  value       = module.defender_for_cloud.security_benchmark_assignment_id
}