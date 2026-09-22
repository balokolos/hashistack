job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "prometheus" {

    count = 1

    network {
      mode = "bridge"
      port "http" {
        static = 9090
        to = 9090
      }
    }

    volume "prometheus-data" {
      type      = "host"
      source    = "prometheus-data"
      read_only = false
    }

    service {
      name     = "prometheus"
      port     = "http"
      provider = "consul"

      connect {
        sidecar_service {
          tags = ["traefik.enable=false"]
        }
      }

      check {
        type     = "http"
        path     = "/-/ready"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"

        args = [
          "--config.file=/local/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.time=7d",
          "--web.enable-lifecycle"
        ]

        ports = [
          "http"
        ]
      }

      template {
        destination = "local/prometheus.yml"

        data = <<EOF
global:
  scrape_interval: 15s

  evaluation_interval: 15s

scrape_configs:

  - job_name: "prometheus"

    static_configs:
      - targets:
          - "localhost:9090"

  - job_name: "consul-services"

    consul_sd_configs:
      - server: "172.17.244.60:8500"
        datacenter: "dc1"

    relabel_configs:

      - source_labels: [__meta_consul_service]
        target_label: service

      - source_labels: [__meta_consul_node]
        target_label: node
EOF
      }

      volume_mount {
        volume      = "prometheus-data"
        destination = "/prometheus"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}
