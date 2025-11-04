terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
  required_version = ">= 1.4.0"
}

provider "aws" {
  region = var.region
}

# Consul module
module "consul" {
  source  = "hashicorp/consul/aws"
  version = ">= 0.1.0"

  cluster_name       = "${var.name}-consul"
  region             = var.region
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnets
  public_subnet_ids  = var.public_subnets
  ssh_key_name       = var.key_name
  server_count       = var.consul_server_count
  client_count       = var.consul_client_count
}

# Vault module
module "vault" {
  source  = "hashicorp/vault/aws"
  version = ">= 0.1.0"

  name          = "${var.name}-vault"
  region        = var.region
  vpc_id        = var.vpc_id
  subnet_ids    = var.private_subnets
  ssh_key_name  = var.key_name
  cluster_size  = var.vault_cluster_size

  enable_auto_unseal = var.enable_auto_unseal
  kms_key_id         = var.kms_key_id
}

# Nomad module
module "nomad" {
  source  = "hashicorp/nomad/aws"
  version = ">= 0.1.0"

  cluster_name = "${var.name}-nomad"
  region       = var.region
  vpc_id       = var.vpc_id
  subnet_ids   = var.private_subnets
  ssh_key_name = var.key_name
  server_count = var.nomad_server_count
  client_count = var.nomad_client_count

  consul_address = module.consul.cluster_address
  vault_address  = module.vault.vault_address
}

# Example outputs (use load balancer or NLB in prod)
output "nomad_address" {
  value = module.nomad.server_ips
}

output "vault_address" {
  value = module.vault.vault_address
}

output "consul_address" {
  value = module.consul.cluster_address
}
