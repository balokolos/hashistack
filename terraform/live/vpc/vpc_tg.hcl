include "root" { path = find_in_parent_folders() }

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  region          = "ap-southeast-1"
  name            = "vo-main"
  cidr            = "10.20.0.0/16"
  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnets  = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnets = ["10.20.10.0/24", "10.20.11.0/24"]
}
