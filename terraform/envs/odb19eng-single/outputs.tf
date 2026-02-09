output "lab_name_core" {
  description = "Core lab name segment used in resource names."
  value       = local.lab_name_core
}

output "vcn_id" {
  description = "OCID of the lab VCN."
  value       = module.network.vcn_id
}

output "public_subnet_id" {
  description = "OCID of the public subnet."
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "OCID of the private subnet."
  value       = module.network.private_subnet_id
}

output "jumphost_public_ip" {
  description = "Public IP address of the jumphost/gateway."
  value       = module.jumphost_gateway.public_ip
}

output "jumphost_private_ip" {
  description = "Private IP address of the jumphost/gateway."
  value       = module.jumphost_gateway.private_ip
}
