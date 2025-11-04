job "example-web" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    count = 2

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:stable"
        port_map { http = 80 }
      }

      resources {
        cpu    = 200
        memory = 128
      }

      env {
        ENV = "prod"
      }

      service {
        name = "example-web"
        port = "http"
        tags = ["nginx"]

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    network {
      port "http" { to = 80 }
    }
  }
}
