job "alloy" {
  datacenters = ["dc1"]
  type        = "system"

  group "alloy" {

    network {
      mode = "bridge"

      port "http" {
        static = 12345
        to     = 12345
      }
    }

    service {
      name     = "alloy"
      port     = "http"
      provider = "consul"

      connect {
        sidecar_service {
          tags = ["traefik.enable=false"]

          proxy {
            upstreams {
              destination_name = "loki"
              local_bind_port  = 3100
            }
          }
        }
      }

      check {
        type     = "http"
        path     = "/-/ready"
        interval = "15s"
        timeout  = "3s"
      }
    }

    volume "alloy-data" {
      type      = "host"
      source    = "alloy-data"
      read_only = false
    }

    task "alloy" {
      driver = "docker"

      config {
        image = "grafana/alloy:latest"

        args = [
          "run",
          "--server.http.listen-addr=0.0.0.0:12345",
          "--storage.path=/var/lib/alloy/data",
          "/local/config.alloy"
        ]

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
      }

      template {
        destination = "local/config.alloy"

        data = <<EOF
logging {
  level  = "info"
  format = "logfmt"
}

discovery.docker "containers" {
  host = "unix:///var/run/docker.sock"
}

discovery.relabel "docker_logs" {
  targets = discovery.docker.containers.targets

  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/(.*)"
    target_label  = "container"
    replacement   = "$1"
  }

  rule {
    source_labels = ["__meta_docker_container_image"]
    target_label  = "image"
  }

  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/(connect-proxy-)?(.+)-[0-9a-f]{8}-[0-9a-f-]{27}"
    target_label  = "group"
    replacement   = "$2"
  }
}

loki.source.docker "containers" {
  host = "unix:///var/run/docker.sock"

  targets = discovery.relabel.docker_logs.output

  labels = {
    job = "docker",
  }

  forward_to = [
    loki.write.default.receiver,
  ]
}

loki.write "default" {
  endpoint {
    url = "http://localhost:3100/loki/api/v1/push"
  }
}
EOF
      }

      volume_mount {
        volume      = "alloy-data"
        destination = "/var/lib/alloy/data"
      }

      resources {
        cpu    = 300
        memory = 256
      }
    }
  }
}
