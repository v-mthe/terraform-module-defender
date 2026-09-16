# Inputs keep subscription security resources separate from LAW-owned resources.
variable "subscription_resource_id" {
  description = "Azure subscription resource ID to protect."
  type        = string
}

variable "location" {
  description = "Azure region for workspace solutions and continuous export."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for Defender continuous export automation."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace used by Defender."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace used by Defender."
  type        = string
}

variable "log_analytics_location" {
  description = "Azure region of the Log Analytics workspace."
  type        = string
}

variable "log_analytics_resource_group_name" {
  description = "Resource group containing the Log Analytics workspace."
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
  }))
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
  description = "Enable agentless VM scanning."
  type        = bool
  default     = true
}

variable "enable_continuous_export" {
  description = "Export Defender findings to Log Analytics."
  type        = bool
  default     = true
}

variable "enable_workspace_solutions" {
  description = "Install Security workspace solutions."
  type        = bool
  default     = true
}