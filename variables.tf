# Target subscription and environment controls.
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

# Defender alert recipient settings.
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

# Subscription-level Defender pricing configuration approved by the security team.
variable "defender_plans" {
  description = "Subscription-level Defender plans, subplans, and optional pricing extensions."
  type = map(object({
    tier    = optional(string, "Standard")
    subplan = optional(string)
    extensions = optional(map(object({
      enabled                         = bool
      additional_extension_properties = optional(map(string), {})
    })), {})
  }))
  default = {
    VirtualMachines = {
      subplan = "P1"
    }
    AppServices                   = {}
    SqlServers                    = {}
    SqlServerVirtualMachines      = {}
    OpenSourceRelationalDatabases = {}
    CosmosDbs                     = {}
    StorageAccounts = {
      subplan = "DefenderForStorageV2"
      extensions = {
        OnUploadMalwareScanning = { enabled = true }
        SensitiveDataDiscovery  = { enabled = true }
      }
    }
    Containers = {
      extensions = {
        ContainerRegistriesVulnerabilityAssessments = { enabled = true }
        AgentlessDiscoveryForKubernetes             = { enabled = true }
        AgentlessVmScanning                         = { enabled = true }
        ContainerSensor                             = { enabled = true }
        ContainerIntegrityContribution              = { enabled = true }
      }
    }
    AI = {
      extensions = {
        AIModelScanner             = { enabled = true }
        AIPromptEvidence           = { enabled = true }
        AIPromptSharingWithPurview = { enabled = true }
      }
    }
    Api = {
      subplan = "P1"
    }
    KeyVaults = {
      subplan = "PerKeyVault"
    }
    Arm = {
      subplan = "PerSubscription"
    }
  }

  validation {
    condition = alltrue([
      for name, plan in var.defender_plans : name != "Api" || contains(["P1", "P2", "P3", "P4", "P5"], plan.subplan == null ? "" : plan.subplan)
    ])
    error_message = "Defender for APIs requires a subplan from P1 through P5."
  }
}

# Optional policy, endpoint, and scanning integrations.
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
  description = "Enable agentless VM scanning. Requires Defender for Servers P2."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_agentless_vm_scanning || try(var.defender_plans["VirtualMachines"].subplan, null) != "P1"
    error_message = "Agentless VM scanning is a Defender for Servers P2 feature and must be disabled when VirtualMachines uses P1."
  }
}
