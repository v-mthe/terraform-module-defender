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

  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

provider "azurerm" {
  alias = "log_analytics"

  features {}

  subscription_id                 = local.log_analytics_subscription_id
  resource_provider_registrations = "none"
}

provider "azapi" {}