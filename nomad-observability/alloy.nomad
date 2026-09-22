job "alloy" {
  datacenters = ["dc1"]
  type        = "system"

  group "alloy" {

    network {
      mode = "host"

      port "http" {
        static = 12345
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

        network_mode = "host"

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

loki.source.docker "containers" {
  host = "unix:///var/run/docker.sock"

  targets = discovery.docker.containers.targets

  labels = {
    job = "docker",
  }

  forward_to = [
    loki.write.default.receiver,
  ]
}

loki.write "default" {
  endpoint {
    url = "http://loki.service.consul:3100/loki/api/v1/push"
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
