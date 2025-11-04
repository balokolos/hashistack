output "nomad_address" {
  value = module.nomad.server_ips
}

output "vault_address" {
  value = module.vault.vault_address
}

output "consul_address" {
  value = module.consul.cluster_address
}
