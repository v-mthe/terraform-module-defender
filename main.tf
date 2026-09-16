data "azurerm_subscription" "current" {}

# Configure subscription-level Defender capabilities through the reusable module.
module "defender_for_cloud" {
  source = "./modules/defender_for_cloud"

  subscription_resource_id     = data.azurerm_subscription.current.id
  security_contact_email       = var.security_contact_email
  security_contact_phone       = var.security_contact_phone
  defender_plans               = var.defender_plans
  adopt_existing_resources     = var.adopt_existing_resources
  assign_security_benchmark    = var.assign_security_benchmark
  enable_mde_integration       = var.enable_mde_integration
  enable_mdvm                  = var.enable_mdvm
  enable_agentless_vm_scanning = var.enable_agentless_vm_scanning
}