# Module-level constraints allow compatible provider updates within the tested major versions.
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.21.0, < 5.0.0"
      # Workspace solutions may be deployed to a separate monitoring subscription.
      configuration_aliases = [
        azurerm.log_analytics,
      ]
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0.0, < 3.0.0"
    }
  }
}