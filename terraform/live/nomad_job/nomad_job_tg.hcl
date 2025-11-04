include "root" { path = find_in_parent_folders() }

terraform {
  source = "../../../modules/nomad-job"
}

dependency "hashistack" {
  config_path = "../hashistack"
}

inputs = {
  # pick first available nomad address output (module returns list)
  nomad_address = dependency.hashistack.outputs.nomad_address[0]
  nomad_token   = "<YOUR-NOMAD-ADMIN-TOKEN>"
}
