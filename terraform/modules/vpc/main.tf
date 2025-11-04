terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
  required_version = ">= 1.4.0"
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.0.0"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true
}
