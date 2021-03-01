terraform {

  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.1.0"
    }
  }

  required_version = "~> 0.14"
}
