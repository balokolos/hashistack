job "grafana" {
  datacenters = ["dc1"]
  type        = "service"

  group "grafana" {

    count = 1

    network {
      mode = "bridge"      
      port "http" {
        to = 3000
      }
    }

    volume "grafana-data" {
      type      = "host"
      source    = "grafana-data"
      read_only = false
    }

    service {
      name     = "grafana"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",

        "traefik.http.routers.grafana.rule=Host(`grafana.balokolos.com`)",

        "traefik.http.routers.grafana.entrypoints=websecure",

        "traefik.http.routers.grafana.tls=true",

      ]

      connect {
        sidecar_service {
          tags = ["traefik.enable=false"]

          proxy {
            upstreams {
              destination_name = "prometheus"
              local_bind_port  = 9090
            }

            upstreams {
              destination_name = "loki"
              local_bind_port  = 3100
            }
          }
        }
      }

      check {
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"

        ports = [
          "http"
        ]
      }

      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
      }

      env {
        GF_SECURITY_ADMIN_USER     = "admin"
        GF_SECURITY_ADMIN_PASSWORD = "admin"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
