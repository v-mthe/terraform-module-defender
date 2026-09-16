# Subscription scope input.
variable "subscription_resource_id" {
  description = "Azure subscription resource ID to protect."
  type        = string
}

# Defender security contact and pricing inputs.
variable "security_contact_email" {
  description = "Email address that receives Defender security alerts."
  type        = string
}

variable "security_contact_phone" {
  description = "Optional E.164 phone number for the Defender security contact."
  type        = string
  default     = null
  nullable    = true
}

variable "defender_plans" {
  description = "Map of Microsoft.Security pricing resource names and settings."
  type = map(object({
    tier    = optional(string, "Standard")
    subplan = optional(string)
    extensions = optional(map(object({
      enabled                         = bool
      additional_extension_properties = optional(map(string), {})
    })), {})
  }))
}

variable "adopt_existing_resources" {
  description = "Use non-destructive updates for existing Defender pricing resources."
  type        = bool
  default     = false
}

# Optional Defender platform capabilities.
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
  description = "Use Microsoft Defender Vulnerability Management."
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
