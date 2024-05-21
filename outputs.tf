output "client_certificate" {
  sensitive = true
  value     = local.client_certificate_pem
}

output "client_key" {
  sensitive = true
  value     = local.client_key_pem
}

output "cluster_ca_certificate" {
  sensitive = true
  value     = local.cluster_ca_certificate_pem
}

output "config" {
  value = ssh_resource.retrieve_config.result
}
