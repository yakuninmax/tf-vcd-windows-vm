variable "allow_external_rdp" {
  type        = bool
  description = "Allow external RDP connections"
  default     = false
}

variable "allow_external_ssh" {
  type        = bool
  description = "Allow external SSH connections"
  default     = false
}

variable "cores_per_socket" {
  type        = number
  description = "Number of cores per socket"
  default     = 1
}

variable "cpus" {
  type        = number
  description = "Number of virtual CPUs"
}

variable "data_disks" {
  type = list(object({
    letter          = string
    size            = number
    storage_profile = string
    block_size      = string
  }))

  description = "VM hard drives"
  default     = []
}

variable "domain_fqdn" {
  type        = string
  description = "AD domain FQDN"
  default     = null
}

variable "domain_password" {
  type        = string
  description = "Domain user password"
  default     = null
}

variable "domain_user" {
  type        = string
  description = "AD domain user name"
  default = null
}

variable "external_ip" {
  type        = string
  description = "VM external IP address"
  default     = ""
}

variable "external_rdp_port" {
  type        = string
  description = "External RDP port"
  default     = ""
}

variable "external_ssh_port" {
  type        = string
  description = "External SSH port"
  default     = ""
}

variable "local_admin_password" {
  type        = string
  description = "Local administrator account password"
  default     = null
  sensitive   = true
}

variable "media" {
  type = object({
    catalog = string
    name    = string
  })

  default     = null
  description = "Media for VM CD/DVD drive"
}

variable "name" {
  type        = string
  description = "VM name"
  
  validation {
    condition     = length(var.name) <= 15
    error_message = "Length must be less or equal 15 characters."
  }
}

variable "nics" {
  type = list(object({
    network        = string
    ip             = string
  }))

  description = "Additional VM hard drives"  
}

variable "ou" {
  type        = string
  description = "Organizational unit for machine account placement"
  default     = null
}

variable "ram" {
  type        = number
  description = "Memory amount in gigabytes"
}

variable "storage_profile" {
  type        = string
  description = "VM storage profile"
  default     = null
}

variable "system_disk_size" {
  type        = number
  description = "VM system disk size in gigabytes"
  default     = 40
}

variable "system_disk_bus" {
  type        = string
  description = "VM system disk bus type"
  default     = "sas"
}

variable "template" {
  type = object({
    catalog = string
    name    = string
  })
  
  description = "Windows VM template"
}

variable "update" {
  type        = bool
  descritpion = "Set true to install Windows updates"
  default     = false
}

variable "vapp" {
  type        = string
  description = "vAPP name"
}