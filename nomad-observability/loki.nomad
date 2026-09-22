job "loki" {
  datacenters = ["dc1"]
  type        = "service"

  group "loki" {

    count = 1

    network {
      port "http" {
        to = 3100
      }
    }

    volume "loki-data" {
      type      = "host"
      source    = "loki-data"
      read_only = false
    }

    service {
      name     = "loki"
      port     = "http"
      provider = "consul"

      check {
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "loki" {
      driver = "docker"

      config {
        image = "grafana/loki:3.7.0"

        args = [
          "-config.file=/local/loki-config.yaml"
        ]

        ports = [
          "http"
        ]
      }

      template {
        destination = "local/loki-config.yaml"

        data = <<EOF
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki

  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules

  replication_factor: 1

  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  allow_structured_metadata: true
  volume_enabled: true

ruler:
  enable_api: true
EOF
      }

      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}
