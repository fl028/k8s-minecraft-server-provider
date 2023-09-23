variable "AZURE_SUBSCRIPTION_ID" {
  description = "Azure config"
  type        = string
}

variable "AZURE_TENANT_ID" {
  description = "Azure config"
  type        = string
}

variable "AZURE_CLIENT_ID" {
  description = "Azure config"
  type        = string
}

variable "AZURE_CLIENT_SECRET" {
  description = "Azure config"
  type        = string
}

variable "SERVER_DOMAIN" {
  description = "Your server domain name"
  type        = string
  default     = "fl028"
}

variable "PROJECT_ROOT_PATH" {
  description = "Path to the project root directory"
  type        = string
}

variable "resource_group_location" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "azureadmin"
}

