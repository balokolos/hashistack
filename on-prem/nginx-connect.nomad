job "nginx-connect" {
  datacenters = ["dc1"]
  group "web" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }
    service {
      name = "nginx"
      port = "http"
      connect {
        sidecar_service {}
      }
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }
    task "nginx" {
      driver = "docker"
      config {
        image = "nginx:latest"
        ports = ["http"]
      }
      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}