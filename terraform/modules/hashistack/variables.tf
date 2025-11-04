variable "region" { type = string }
variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnets" { type = list(string) }
variable "public_subnets" { type = list(string) }
variable "key_name" { type = string }

variable "kms_key_id" { type = string }
variable "enable_auto_unseal" { type = bool, default = true }

variable "consul_server_count" { type = number, default = 3 }
variable "consul_client_count" { type = number, default = 2 }
variable "vault_cluster_size" { type = number, default = 3 }
variable "nomad_server_count" { type = number, default = 3 }
variable "nomad_client_count" { type = number, default = 3 }
