output "external-ip" {
  value = var.allow_external_ssh == false ? var.allow_external_rdp == false ? "" : var.external_ip != "" ? var.external_ip : data.vcd_edgegateway.edge.external_network_ips[0] : var.external_ip != "" ? var.external_ip : data.vcd_edgegateway.edge.external_network_ips[0]
}

output "external-ssh-port" {
  value = var.allow_external_ssh == true ? var.external_ssh_port != "" ? var.external_ssh_port : random_integer.ssh-port[0].result : ""
}

output "external-rdp-port" {
  value = var.allow_external_rdp == true ? var.external_rdp_port != "" ? var.external_rdp_port : random_integer.rdp-port[0].result : ""
}

output "internal-ip" {
  value = vcd_vapp_vm.vm.network[0].ip
}

output "name" {
  value = vcd_vapp_vm.vm.name
}

output "password" {
  value     = vcd_vapp_vm.vm.customization[0].admin_password
  sensitive = true
}
