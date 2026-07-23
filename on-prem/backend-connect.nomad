job "backend-connect" {
  datacenters = ["dc1"]
  group "api" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        to = 8080
      }
    }
    service {
      name = "backend"
      port = "http"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "nginx"
              local_bind_port  = 9090
            }
          }
        }
      }
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }
    task "server" {
      driver = "docker"
      config {
        image = "hashicorp/demo-webapp-lb-guide"
        ports = ["http"]
      }
      env {
        PORT = "8080"
        NODE_IP      = "${NOMAD_IP_http}"
        UPSTREAM_URL = "http://localhost:9090"
      }
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}