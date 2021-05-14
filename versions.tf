terraform {

  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.2.0"
    }
  }

  required_version = "~> 0.15"
}
