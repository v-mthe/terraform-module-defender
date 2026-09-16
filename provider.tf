# Provider and state requirements for the Defender root configuration.
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.21.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }

  # Backend coordinates and the environment-specific key are supplied at init time.
  backend "azurerm" {}
}

# The deployment subscription is selected explicitly through tfvars.
provider "azurerm" {
  features {}

  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

# AzAPI manages Defender resources not supported by the pinned AzureRM provider.
provider "azapi" {}