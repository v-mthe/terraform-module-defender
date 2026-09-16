variable "subscription_id" {
  description = "Azure subscription ID where Defender for Cloud will be configured."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "adopt_existing_resources" {
  description = "Adopt existing subscription-level Defender resources into Terraform state. Enable for brownfield or previously onboarded subscriptions."
  type        = bool
  default     = false
}

variable "location" {
  description = "Azure region for Defender monitoring resources."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group for Defender monitoring resources."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace used by Defender for Cloud."
  type        = string
}

variable "log_analytics_sku" {
  description = "Log Analytics workspace SKU."
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_in_days" {
  description = "Log Analytics retention period."
  type        = number
  default     = 90
}

variable "security_contact_email" {
  description = "Email address that receives Defender for Cloud security alerts."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.security_contact_email))
    error_message = "security_contact_email must be a valid email address."
  }
}

variable "security_contact_phone" {
  description = "Optional E.164 phone number for the security contact."
  type        = string
  default     = null
  nullable    = true
}

variable "defender_plans" {
  description = "Defender plans shown as On in the security team's test scope. APIs are intentionally omitted."
  type = map(object({
    tier    = optional(string, "Standard")
    subplan = optional(string)
  }))
  default = {
    VirtualMachines = {
      subplan = "P2"
    }
    AppServices                   = {}
    SqlServers                    = {}
    SqlServerVirtualMachines      = {}
    OpenSourceRelationalDatabases = {}
    CosmosDbs                     = {}
    StorageAccounts = {
      subplan = "DefenderForStorageV2"
    }
    Containers = {}
    AI         = {}
    KeyVaults = {
      subplan = "PerKeyVault"
    }
    Arm = {
      subplan = "PerSubscription"
    }
  }

  validation {
    condition     = !contains(keys(var.defender_plans), "Api")
    error_message = "The security test scope requires Defender for APIs to remain Off; remove Api from defender_plans."
  }
}

variable "assign_security_benchmark" {
  description = "Assign the Microsoft Cloud Security Benchmark initiative."
  type        = bool
  default     = true
}

variable "enable_mde_integration" {
  description = "Enable Microsoft Defender for Endpoint integration."
  type        = bool
  default     = true
}

variable "enable_mdvm" {
  description = "Use Microsoft Defender Vulnerability Management for server vulnerability assessment."
  type        = bool
  default     = true
}

variable "enable_agentless_vm_scanning" {
  description = "Enable agentless VM scanning."
  type        = bool
  default     = true
}

variable "enable_continuous_export" {
  description = "Export medium/high alerts, secure scores, and controls to Log Analytics."
  type        = bool
  default     = true
}

variable "enable_workspace_solutions" {
  description = "Install Security and SecurityCenterFree solutions in Log Analytics."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to resources created by the root module."
  type        = map(string)
  default     = {}
}