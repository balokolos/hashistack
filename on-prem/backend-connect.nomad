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
              local_bind_port  = 9094
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
        #image = "hashicorp/demo-webapp-lb-guide"
        image = "nicholasjackson/fake-service:v0.26.0"
        ports = ["http"]
      }
      env {
        # PORT = "8080"
        # NODE_IP      = "${NOMAD_IP_http}"
        # UPSTREAM_URL = "http://localhost:9090"
        LISTEN_ADDR   = "0.0.0.0:8080"
        NAME          = "backend"
        UPSTREAM_URIS = "http://localhost:9094"
      }
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}