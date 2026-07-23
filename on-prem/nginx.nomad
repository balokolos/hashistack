job "nginx" {
  datacenters = ["dc1"]
  group "web" {
    count = 1
    network {
      port "http" {
        to = 80
      }
    }
    service {
      name = "nginx"
      port = "http"
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