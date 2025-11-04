locals {
  region = "ap-southeast-1"
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "<YOUR-TERRAGRUNT-STATE-BUCKET>"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "<YOUR-TERRAGRUNT-LOCKS-TABLE>"
  }
}
