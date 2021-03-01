# Create VM
resource "vcd_vapp_vm" "vm" {
  vapp_name       = var.vapp
  name            = var.name
  catalog_name    = var.template.catalog
  template_name   = var.template.name
  memory          = var.ram * 1024
  cpus            = var.cpus
  cpu_cores       = var.cores_per_socket
  storage_profile = var.storage_profile
  computer_name   = var.name

  override_template_disk {
    size_in_mb      = var.system_disk_size * 1024
    bus_type        = var.system_disk_bus
    bus_number      = 0
    unit_number     = 0
  }
  
  dynamic "network" {
    for_each = var.nics
      content {
        type               = "org"
        name               = network.value["network"]
        ip_allocation_mode = network.value["ip"] != "" ? "MANUAL" : "POOL"
        ip                 = network.value["ip"] != "" ? network.value["ip"] : null
      }
  }

  customization {
    enabled                    = true
    change_sid                 = true
    allow_local_admin_password = true
    auto_generate_password     = var.local_admin_password != null ? false : true
    admin_password             = var.local_admin_password != null ? var.local_admin_password : null
    join_domain                = var.domain_fqdn != null ? true : false
    join_domain_name           = var.domain_fqdn != null ? var.domain_fqdn : null
    join_domain_user           = var.domain_fqdn != null ? var.domain_user : null
    join_domain_password       = var.domain_fqdn != null ? var.domain_password : null
    join_domain_account_ou     = var.domain_fqdn != null ? var.ou != "" ? var.ou : null : null
  }
}

# Add VM data disks
resource "vcd_vm_internal_disk" "disk" {
  count = length(var.data_disks)
  
  vapp_name       = vcd_vapp_vm.vm.vapp_name
  vm_name         = vcd_vapp_vm.vm.name
  bus_type        = "paravirtual"
  size_in_mb      = var.data_disks[count.index].size * 1024
  bus_number      = 1
  unit_number     = count.index
  storage_profile = var.data_disks[count.index].storage_profile != "" ? var.data_disks[count.index].storage_profile : ""
}

# Insert media
resource "vcd_inserted_media" "media" {
  count = var.media != null ? 1 : 0
  depends_on = [ vcd_vm_internal_disk.disk ]

  vapp_name = vcd_vapp_vm.vm.vapp_name
  vm_name   = vcd_vapp_vm.vm.name
  catalog   = var.media.catalog
  name      = var.media.name
  eject_force = true
}

# Get random SSH port
resource "random_integer" "ssh-port" {
  count = var.allow_external_ssh == true ? 1 : 0
  
  min     = 40000
  max     = 49999
}

# Get random RDP port
resource "random_integer" "rdp-port" {
  count = var.allow_external_rdp == true ? 1 : 0

  min     = 50000
  max     = 59999
}

# SSH DNAT rule
resource "vcd_nsxv_dnat" "ssh-dnat-rule" {
  count = var.allow_external_ssh == true ? 1 : 0
  
  edge_gateway = data.vcd_edgegateway.edge.name
  network_type = "ext"
  network_name = tolist(data.vcd_edgegateway.edge.external_network)[0].name  

  original_address   = data.vcd_edgegateway.edge.external_network_ips[0]
  original_port      = var.external_ssh_port != "" ? var.external_ssh_port : random_integer.ssh-port[0].result
  translated_address = vcd_vapp_vm.vm.network[0].ip
  translated_port    = "22"
  protocol           = "tcp"

  description = "SSH to ${vcd_vapp_vm.vm.name}"
}

# SSH firewall rule
resource "vcd_nsxv_firewall_rule" "ssh-firewall-rule" {  
  count = var.allow_external_ssh == true ? 1 : 0

  edge_gateway = data.vcd_edgegateway.edge.name
  name         = "SSH to ${vcd_vapp_vm.vm.name}"

  source {
    ip_addresses = [trimspace(data.http.terraform-external-ip.body)]
  }

  destination {
    ip_addresses = [data.vcd_edgegateway.edge.external_network_ips[0]]
  }

  service {
    protocol = "tcp"
    port     = var.external_ssh_port != "" ? var.external_ssh_port : random_integer.ssh-port[0].result
  }
}

# RDP DNAT rule
resource "vcd_nsxv_dnat" "rdp-rule" {
  count = var.allow_external_rdp == true ? 1 : 0
  
  edge_gateway = data.vcd_edgegateway.edge.name
  network_type = "ext"
  network_name = tolist(data.vcd_edgegateway.edge.external_network)[0].name  

  original_address   = data.vcd_edgegateway.edge.external_network_ips[0]
  original_port      = var.external_rdp_port != "" ? var.external_rdp_port : random_integer.rdp-port[0].result
  translated_address = vcd_vapp_vm.vm.network[0].ip
  translated_port    = "3389"
  protocol           = "tcp"

  description = "RDP to ${vcd_vapp_vm.vm.name}"
}

# RDP firewall rule
resource "vcd_nsxv_firewall_rule" "rdp-firewall-rule" {  
  count = var.allow_external_rdp == true ? 1 : 0

  edge_gateway = data.vcd_edgegateway.edge.name
  name         = "RDP to ${vcd_vapp_vm.vm.name}"

  source {
    ip_addresses = [trimspace(data.http.terraform-external-ip.body)]
  }

  destination {
    ip_addresses = [data.vcd_edgegateway.edge.external_network_ips[0]]
  }

  service {
    protocol = "tcp"
    port     = var.external_rdp_port != "" ? var.external_rdp_port : random_integer.rdp-port[0].result
  }
}

# Set default shell for SSH
resource "null_resource" "set-default-shell" {
  depends_on = [ vcd_vapp_vm.vm ]

  provisioner "remote-exec" {
    
    connection {
      type        = "ssh"
      user        = "Administrator"
      password    = vcd_vapp_vm.vm.customization[0].admin_password
      host        = var.allow_external_ssh == true ? var.external_ip != "" ? var.external_ip : data.vcd_edgegateway.edge.external_network_ips[0] : vcd_vapp_vm.vm.network[0].ip
      port        = var.allow_external_ssh == true ? var.external_ssh_port != "" ? var.external_ssh_port : random_integer.ssh-port[0].result : 22
      script_path = "/Windows/Temp/terraform_%RAND%.ps1"
      timeout     = "15m"
    }

    inline = [
                "reg add HKLM\\SOFTWARE\\OpenSSH /v DefaultShell /t REG_SZ /d C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe /f"
             ]
  }
}

# Initial OS configuration
resource "null_resource" "initial-config" {
  depends_on = [ null_resource.set-default-shell ]

  provisioner "remote-exec" {
    
    connection {
      type        = "ssh"
      user        = "Administrator"
      password    = vcd_vapp_vm.vm.customization[0].admin_password
      host        = var.allow_external_ssh == true ? var.external_ip != "" ? var.external_ip : data.vcd_edgegateway.edge.external_network_ips[0] : vcd_vapp_vm.vm.network[0].ip
      port        = var.allow_external_ssh == true ? var.external_ssh_port != "" ? var.external_ssh_port : random_integer.ssh-port[0].result : 22
      script_path = "/Windows/Temp/terraform_%RAND%.ps1"
      timeout     = "15m"
    }

    inline = [
                "Get-Partition -DriveLetter C | Resize-Partition -Size (Get-PartitionSupportedSize -DriveLetter C).sizeMax -Confirm:$false -ErrorAction SilentlyContinue",
                "Set-WmiInstance -InputObject (Get-WmiObject -Class Win32_volume -Filter 'DriveLetter = \"D:\"') -Arguments @{DriveLetter=([char]([int][char]\"D\" + ${length(var.data_disks)}) + \":\")}",
                "New-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0 -Force",
                "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'",
                "Enable-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)'",
                "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Wow6432Node\\Microsoft\\.NetFramework\\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord -Force -Confirm:$false",
                "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\.NetFramework\\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord -Force -Confirm:$false"
             ]
  }
}

# Data disk configuration
resource "null_resource" "disk-config" {
  count = length(var.data_disks)
  depends_on = [ null_resource.initial-config ]

  provisioner "remote-exec" {
    
    connection {
      type        = "ssh"
      user        = "Administrator"
      password    = vcd_vapp_vm.vm.customization[0].admin_password
      host        = var.allow_external_ssh == true ? var.external_ip != "" ? var.external_ip : data.vcd_edgegateway.edge.external_network_ips[0] : vcd_vapp_vm.vm.network[0].ip
      port        = var.allow_external_ssh == true ? var.external_ssh_port != "" ? var.external_ssh_port : random_integer.ssh-port[0].result : 22
      script_path = "/Windows/Temp/terraform_%RAND%.ps1"
      timeout     = "15m"
    }

    inline = [
                "Get-Disk -Number (Get-WmiObject -Class Win32_DiskDrive | ?{$_.SCSIPort -ne '0' -and $_.SCSITargetId -eq ${count.index}}).Index | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter ${var.data_disks[count.index].letter} -UseMaximumSize",
                "Format-Volume -DriveLetter ${var.data_disks[count.index].letter} -FileSystem NTFS -AllocationUnitSize ${var.data_disks[count.index].block_size != "" ? var.data_disks[count.index].block_size * 1024 : 4096} -Confirm:$false"
             ]
  }
}
