# Copyright IBM Corp. 2015, 2026
# SPDX-License-Identifier: BUSL-1.1

# Full configuration options can be found at https://developer.hashicorp.com/nomad/docs/configuration

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

server {
  # license_path is required for Nomad Enterprise as of Nomad v1.1.1+
  #license_path = "/etc/nomad.d/license.hclic"
  enabled          = true
  bootstrap_expect = 1
}

client {
  enabled = true
  servers = ["172.17.244.60"]
  cni_path = "/opt/cni/bin"
  host_volume "prometheus-data" {
    path      = "/opt/monitoring/prometheus/data"
    read_only = false
  }

  host_volume "loki-data" {
    path      = "/opt/monitoring/loki/data"
    read_only = false
  }

  host_volume "grafana-data" {
    path      = "/opt/monitoring/grafana/data"
    read_only = false
  }

  host_volume "alloy-data" {
    path      = "/opt/monitoring/alloy/data"
    read_only = false
  }
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}

telemetry {
  collection_interval        = "1s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}