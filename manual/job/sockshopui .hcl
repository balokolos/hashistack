job "sockshopui" {
  datacenters = ["dc1"]
  type        = "system"

  group "frontend" {
    network {
      port "http" {
        static = 80
        to     = 8079
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "front-end" {
      driver = "docker"

      config {
        image   = "weaveworksdemos/front-end:master-ac9ca707"
        command = "/usr/local/bin/node"
        args    = ["server.js", "--domain=service.consul"]
        hostname = "front-end.service.consul"
        ports    = ["http"]
      }

      service {
        name = "front-end"
        tags = ["app", "frontend", "front-end"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
