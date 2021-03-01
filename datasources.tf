# Get default vCD org edge info
data "vcd_edgegateway" "edge" {
  filter {
    name_regex = "^.*$"
  }
}

# Get Terraform host external IP
data "http" "terraform-external-ip" {
  url = "https://api.my-ip.io/ip"
}