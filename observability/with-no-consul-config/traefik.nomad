job "traefik" {
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {

    network {
      mode = "host"

      port "http" {
        static = 80
      }

      port "https" {
        static = 443
      }

      port "dashboard" {
        static = 8080
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.6"
        network_mode = "host"

        args = [
          "--entrypoints.web.address=:80",
          "--entrypoints.websecure.address=:443",

          "--providers.consulcatalog=true",
          "--providers.consulcatalog.endpoint.address=127.0.0.1:8500",
          "--providers.consulcatalog.exposedbydefault=false",

          "--api.dashboard=true",
	  "--api.insecure=true",

          "--log.level=INFO",
          "--accesslog=true"
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
