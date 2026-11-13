variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "Whether to enable the module's subscription-scoped telemetry deployment."
  nullable    = false
}

variable "location" {
  type        = string
  default     = "eastus2"
  description = "Azure region for the example resources."
  nullable    = false
}
