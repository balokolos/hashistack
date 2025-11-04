include "root" { path = find_in_parent_folders() }

terraform {
  source = "../../../modules/hashistack"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region          = "ap-southeast-1"
  name            = "vo-hashistack"
  vpc_id          = dependency.vpc.outputs.vpc_id
  private_subnets = dependency.vpc.outputs.private_subnets
  public_subnets  = dependency.vpc.outputs.public_subnets
  key_name        = "<YOUR-EC2-KEYNAME>"
  kms_key_id      = "<YOUR-KMS-ARN>"
}
