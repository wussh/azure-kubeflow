variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-kubeflow"
}

variable "vm_size" {
  description = "The size of the virtual machine"
  type        = string
  default     = "Standard_E4s_v5"
}

variable "admin_username" {
  description = "The admin username for the virtual machine"
  type        = string
  default     = "azureuser"
}

variable "ssh_key_filename" {
  description = "The filename for the SSH key"
  type        = string
  default     = "vm_key.pem"
}

variable "data_disk_size_gb" {
  description = "The size of the data disk in GB"
  type        = number
  default     = 100
}

variable "os_disk_type" {
  description = "The storage account type for the OS disk"
  type        = string
  default     = "Premium_LRS"
}

variable "data_disk_type" {
  description = "The storage account type for the data disk"
  type        = string
  default     = "Premium_LRS"
} 