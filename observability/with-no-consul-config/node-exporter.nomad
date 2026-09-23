job "node-exporter" {
  datacenters = ["dc1"]
  type        = "system"

  group "node-exporter" {

    network {
      mode = "host"

      port "metrics" {
        static = 9100
      }
    }

    service {
      name     = "node-exporter"
      port     = "metrics"
      provider = "consul"

      check {
        type     = "http"
        path     = "/metrics"
        interval = "15s"
        timeout  = "3s"
      }
    }

    task "node-exporter" {
      driver = "docker"

      config {
        image        = "prom/node-exporter:latest"
        network_mode = "host"

        args = [
          "--web.listen-address=:9100"
        ]

      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
