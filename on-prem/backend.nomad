job "backend" {
  datacenters = ["dc1"]
  group "api" {
    count = 1
    network {
      port "http" {
        to = 8080
      }
    }
    service {
      name = "backend"
      port = "http"
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
        UPSTREAM_URL = "http://nginx.service.consul"
      }
      resources {`
        cpu    = 500
        memory = 256
      }
    }
  }
}