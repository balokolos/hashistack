terraform {
  required_providers {
    nomad = { source = "hashicorp/nomad" }
  }
  required_version = ">= 1.4.0"
}

provider "nomad" {
  address = var.nomad_address
  token   = var.nomad_token
}

# You can set depends_on to ensure external infra is ready; terragrunt dependency already ensures ordering.
resource "nomad_job" "example" {
  jobspec = file("${path.module}/job.nomad")
  detach  = false
}
