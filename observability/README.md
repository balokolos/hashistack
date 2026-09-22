# Nomad Observability Stack

This directory contains a lab-ready Nomad observability stack using Grafana,
Prometheus, Loki, Alloy, node-exporter, Traefik, Consul, and Consul Connect.

## Documentation

- [Nomad Grafana stanza guide](nomad-grafana-stanza-guide.md): explains each Nomad
  stanza using `grafana.nomad` as the example.
- [Consul Connect observability playbook](connect-observability-runbook.md): records
  the root causes, fixes, prerequisites, and verification commands used for this
  stack.

## Job files

- `traefik.nomad`: HTTPS ingress and Consul Catalog discovery.
- `grafana.nomad`: Grafana with Prometheus and Loki Connect upstreams.
- `prometheus.nomad`: Prometheus with Consul service discovery and a Connect sidecar.
- `loki.nomad`: single-binary Loki with a Connect sidecar.
- `alloy.nomad`: Docker log collection and delivery to Loki through Connect.
- `node-exporter.nomad`: one node-exporter system task per Nomad client.
- `deploy-observability.sh`: validates and deploys all jobs in dependency order.

The `.nomad` files are the deployable source of truth. The Markdown files explain
the design and troubleshooting history.

## Known setup problems

- Monitoring data directories must be writable by the container tasks.
- Nomad's Docker plugin must allow volume mounts for the Docker socket.
- Grafana must be reached through the HTTPS host configured in its Traefik tags.
- Grafana's Prometheus and Loki datasources use Connect-local URLs:
  `http://localhost:9090` and `http://localhost:3100`.

## Prerequisites

The Nomad client configuration must define the monitoring host volumes and enable
Docker volume mounts:

```hcl
data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = 1
}

client {
  enabled  = true
  servers  = ["172.17.244.60"]
  cni_path = "/opt/cni/bin"

  host_volume "prometheus-data" {
    path      = "/opt/monitoring/prometheus/data"
    read_only = false
  }

  host_volume "loki-data" {
    path      = "/opt/monitoring/loki/data"
    read_only = false
  }

  host_volume "grafana-data" {
    path      = "/opt/monitoring/grafana/data"
    read_only = false
  }

  host_volume "alloy-data" {
    path      = "/opt/monitoring/alloy/data"
    read_only = false
  }
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}
```

## Deployment walkthrough

This is a lab-ready Nomad and Consul monitoring stack: single-instance Grafana,
Prometheus, and Loki, with Traefik in front and Alloy/node-exporter on Nomad clients.
The architecture is:

```text
                         ┌─────────────────┐
                         │      Users      │
                         └────────┬────────┘
                                  │
                              HTTPS :443
                                  │
                         ┌────────▼────────┐
                         │     Traefik     │
                         │  API Gateway    │
                         └────────┬────────┘
                                  │
                         Consul Catalog
                                  │
                         ┌────────┴────────┐
                         │                 │
                         ▼                 ▼
                    ┌─────────┐       other apps
                    │ Grafana │
                    │  :3000  │
                    └────┬────┘
                         │
                  ┌──────┴──────┐
                  ▼             ▼
             Prometheus       Loki
               :9090          :3100
                  ▲             ▲
                  │             │
             node_exporter    Alloy
                  ▲             ▲
                  │             │
             Nomad clients   Docker logs
```

Nomad can register services directly with Consul from the service blocks in the jobspec, and Traefik's Consul Catalog provider can then discover those services and generate routes from their tags. HashiCorp Developer

## 1. Assumptions
I'm assuming your lab looks roughly like:
nomad-server-1
nomad-client-1
nomad-client-2
nomad-client-3
with:
Nomad
Consul
Docker
already installed.
For the first version, use:
Datacenter: dc1
Consul: 127.0.0.1:8500 on each node
Nomad clients should talk to their local Consul agent, not directly to a Consul server. HashiCorp specifically recommends that each Nomad agent communicate with a unique local Consul agent. HashiCorp Developer

## 2. Directory structure
On the Nomad clients, create:

```text
/opt/monitoring/
├── prometheus/
│   └── data/
├── loki/
│   └── data/
├── grafana/
│   └── data/
└── alloy/
    └── data/
```
For example:
sudo mkdir -p /opt/monitoring/{prometheus,loki,grafana,alloy}/data
For a lab, local disk is fine.
Later, we can change this to:

```text
NFS
  │
  ├── Grafana
  ├── Prometheus
  └── Loki
```
or, preferably for Prometheus, use local SSD plus a suitable remote-storage/backup architecture.

## 3. Nomad host volumes
On the Nomad client that will run the monitoring workloads, configure:

```hcl
host_volume "prometheus-data" {
  path      = "/opt/monitoring/prometheus/data"
  read_only = false
}

host_volume "loki-data" {
  path      = "/opt/monitoring/loki/data"
  read_only = false
}

host_volume "grafana-data" {
  path      = "/opt/monitoring/grafana/data"
  read_only = false
}

host_volume "alloy-data" {
  path      = "/opt/monitoring/alloy/data"
  read_only = false
}
For example, put that in the Nomad client configuration.
Host volumes can then be requested from jobs using the volume and volume_mount blocks. HashiCorp Developer
Restart Nomad after changing the client configuration:
sudo systemctl restart nomad
Check:
nomad node status
```

## 4. Traefik
Create:
traefik.nomad

```hcl
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

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]

        args = [
          "--entrypoints.web.address=:80",
          "--entrypoints.websecure.address=:443",

          "--providers.consulcatalog=true",
          "--providers.consulcatalog.endpoint.address=127.0.0.1:8500",
          "--providers.consulcatalog.exposedbydefault=false",

          "--api.dashboard=true",

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
```
The important part is:

```text
Traefik
   │
   ▼
Consul Catalog
```
rather than Traefik talking directly to Nomad.
Traefik supports providers.consulCatalog, including an endpoint such as 127.0.0.1:8500, and exposedByDefault=false means only services explicitly tagged for Traefik are exposed. Traefik Docs
Deploy:
nomad job run traefik.nomad
Check:
nomad job status traefik

## 5. Grafana
Create:
grafana.nomad

```hcl
job "grafana" {
  datacenters = ["dc1"]
  type        = "service"

  group "grafana" {

    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    volume "grafana-data" {
      type      = "host"
      source    = "grafana-data"
      read_only = false
    }

    service {
      name     = "grafana"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",

        "traefik.http.routers.grafana.rule=Host(`grafana.example.com`)",

        "traefik.http.routers.grafana.entrypoints=websecure",

        "traefik.http.routers.grafana.tls=true",

        "traefik.http.services.grafana.loadbalancer.server.port=3000"
      ]

      check {
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"

        ports = [
          "http"
        ]
      }

      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
      }

      env {
        GF_SECURITY_ADMIN_USER     = "admin"
        GF_SECURITY_ADMIN_PASSWORD = "CHANGE-ME"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
```
Change:
grafana.example.com
to your actual DNS name.
For example:
grafana.sgp.example.com
Deploy:
nomad job run grafana.nomad
Then:
consul catalog services
You should see:
grafana

## 6. Prometheus
Create:
prometheus.nomad
The nice thing about Nomad templates is that we can generate the Prometheus configuration directly inside the allocation.

```hcl
job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "prometheus" {

    count = 1

    network {
      port "http" {
        to = 9090
      }
    }

    volume "prometheus-data" {
      type      = "host"
      source    = "prometheus-data"
      read_only = false
    }

    service {
      name     = "prometheus"
      port     = "http"
      provider = "consul"

      check {
        type     = "http"
        path     = "/-/ready"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"

        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.time=7d",
          "--web.enable-lifecycle"
        ]

        ports = [
          "http"
        ]
      }

      template {
        destination = "local/prometheus.yml"

        data = <<EOF
global:
  scrape_interval: 15s

  evaluation_interval: 15s

scrape_configs:

  - job_name: "prometheus"

    static_configs:
      - targets:
          - "localhost:9090"

  - job_name: "consul-services"

    consul_sd_configs:
      - server: "127.0.0.1:8500"
        datacenter: "dc1"

    relabel_configs:

      - source_labels: [__meta_consul_service]
        target_label: service

      - source_labels: [__meta_consul_node]
        target_label: node
EOF
      }

      volume_mount {
        volume      = "prometheus-data"
        destination = "/prometheus"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}
```
One thing needs fixing here: the generated configuration must be available inside the container. Use the Nomad allocation-relative mount:

```hcl
config {
  image = "prom/prometheus:latest"

  args = [
    "--config.file=/local/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=7d"
  ]

  ports = ["http"]
}
```
Nomad makes local/ available to the task container, so the final config should be:

```hcl
config {
  image = "prom/prometheus:latest"

  args = [
    "--config.file=/local/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=7d"
  ]

  ports = ["http"]
}
```
Deploy:
nomad job run prometheus.nomad

## 7. Node exporter
This should be a system job, because you want one node exporter per Nomad client.
Create:
node-exporter.nomad

```hcl
job "node-exporter" {
  datacenters = ["dc1"]
  type        = "system"

  group "node-exporter" {

    network {
      mode = "host"

      port "metrics" {
        static = 9100
      }
    }

    service {
      name     = "node-exporter"
      port     = "metrics"
      provider = "consul"

      check {
        type     = "http"
        path     = "/metrics"
        interval = "15s"
        timeout  = "3s"
      }
    }

    task "node-exporter" {
      driver = "docker"

      config {
        image        = "prom/node-exporter:latest"
        network_mode = "host"

        args = [
          "--path.rootfs=/host"
        ]

        volumes = [
          "/:/host:ro,rslave"
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```
Deploy:
nomad job run node-exporter.nomad
Then:
consul catalog services
should show:
node-exporter
and:
curl http://localhost:9100/metrics
should return Prometheus metrics.
## 8. Loki
For the first lab, use Loki in single-binary mode.
Grafana's current documentation supports Loki as a single binary for evaluation/testing, while recommending more production-oriented deployment approaches when scaling. Grafana Labs
Create:
loki.nomad

```hcl
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
```
Deploy:
nomad job run loki.nomad
Test:
curl http://localhost:3100/ready
You should get:
ready
Grafana notes that Loki itself does not provide an authentication layer, so if Loki is exposed externally it should sit behind an authenticating reverse proxy. Grafana Labs
That's another reason we're keeping:
Loki :3100
internal.
## 9. Alloy
Now we need logs.
We'll run Alloy as a system job, meaning one Alloy instance per Nomad client.
The basic flow:

```text
Docker
   │
   ▼
Alloy
   │
   │ HTTP push
   ▼
Loki
```
Alloy has a native loki.source.docker component for reading Docker container logs. Grafana Labs
Create:
alloy.nomad

```hcl
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
```
Then:
nomad job run alloy.nomad
The Alloy UI will be available on:
http://NOMAD_CLIENT_IP:12345
The Docker socket gives Alloy access to the Docker daemon, so treat this job as privileged infrastructure. The Nomad Docker driver also needs access to the Docker daemon on the client. HashiCorp Developer
## 10. One important networking issue
This part:
loki.service.consul
requires Consul DNS resolution from inside the Docker container.
Nomad/Consul documentation specifically notes that Docker workloads need suitable DNS configuration to resolve Consul service names. HashiCorp Developer
If your Docker containers cannot resolve:
loki.service.consul
check:
cat /etc/resolv.conf
and your Docker/Consul DNS configuration.
For a lab, you can alternatively use the Consul agent IP:
http://CONSUL_AGENT_IP:3100/loki/api/v1/push
but using Consul DNS is preferable once your DNS integration is correct.
## 11. Deploy order
The deployment order is automated by [`deploy-observability.sh`](deploy-observability.sh):

```bash
./deploy-observability.sh --validate-only
./deploy-observability.sh
```

The script validates every job before submitting any job, then deploys in this order:

Step 1 — node exporter
nomad job run node-exporter.nomad
Check:
consul catalog services

Step 2 — Loki
nomad job run loki.nomad
Check:
curl http://localhost:3100/ready

Step 3 — Prometheus
nomad job run prometheus.nomad
Check:
nomad job status prometheus
Then open:
http://PROMETHEUS-IP:9090

Step 4 — Alloy
nomad job run alloy.nomad
Check:
nomad job status alloy

Step 5 — Grafana
nomad job run grafana.nomad

Step 6 — Traefik
nomad job run traefik.nomad
## 12. Check Consul
Run:
consul catalog services
You should eventually see something like:
alloy
grafana
loki
node-exporter
prometheus
Then:
consul catalog nodes
And:
consul health service grafana
For example:
Service: grafana

Address: 10.0.10.21
Port:    3000
Status:  passing
## 13. Traefik should automatically discover Grafana
This is the important part of the architecture.
Grafana has:
tags = [
  "traefik.enable=true",
  "traefik.http.routers.grafana.rule=Host(`grafana.example.com`)",
  "traefik.http.routers.grafana.entrypoints=websecure",
  "traefik.http.routers.grafana.tls=true",
  "traefik.http.services.grafana.loadbalancer.server.port=3000"
]
So:

```text
Nomad
  │
  │ registers
  ▼
Consul
  │
  │ service + tags
  ▼
Traefik
  │
  │ dynamically creates route
  ▼
Grafana
```
No static Traefik backend configuration is necessary.
This is exactly the type of dynamic routing Traefik's Consul Catalog provider is designed for. Traefik Docs
## 14. Grafana data sources
Once Grafana is running, add:

Prometheus URL: http://prometheus.service.consul:9090 --> changed to localhost with consul connect

Loki URL: http://loki.service.consul:3100 --> changed to localhost with consul connect

So Grafana becomes:

```text
                    Grafana
                   /       \
                  /         \
                 ▼           ▼
          Prometheus         Loki
             :9090          :3100
               ▲              ▲
               │              │
         node-exporter       Alloy
                              │
                              ▼
                           Docker
```
## 15. DNS names
I'd eventually make your external DNS look like:
grafana.example.com
and:
traefik.example.com
But not:
prometheus.example.com
loki.example.com
unless you specifically need external access.
Internally:
grafana.service.consul
prometheus.service.consul
loki.service.consul
node-exporter.service.consul
Externally:
grafana.example.com
## 16. HTTPS
For the next step, add:
```text
Internet/LAN
      │
      │ :443
      ▼
┌───────────────┐
│    Traefik    │
│ TLS termination│
└───────┬───────┘
        │
        ▼
     Grafana
```

Traefik can handle Let's Encrypt/ACME, or you can use your internal CA if this is an infrastructure lab.
Then users only need:
https://grafana.example.com
## 17. What I'd improve after the lab works
Don't jump immediately to HA. First get this working:

```text
                  ┌───────────┐
                  │  Traefik  │
                  └─────┬─────┘
                        │
                        ▼
                    Grafana
                    /      \
                   ▼        ▼
             Prometheus    Loki
                ▲             ▲
                │             │
          node-exporter      Alloy
                │             │
                └──── Nomad ──┘
                       │
                    Consul
```

Then we can make it more production-like:

```text
Phase 2
Traefik
  │
  ├── TLS
  ├── authentication
  ├── rate limiting
  └── access logs
Phase 3
Prometheus
   │
   ├── alerting
   ├── Alertmanager
   └── Consul service discovery
Phase 4
Loki
   │
   ├── object storage
   ├── retention
   └── HA
Phase 5
Grafana
   │
   ├── Prometheus
   ├── Loki
   └── alerting
Phase 6
Use your NAS/SAN knowledge:
                 Storage
              ┌──────┴──────┐
              │             │
             NAS           SAN
              │
             NFS
              │
       ┌──────┴──────┐
       │             │
    Grafana        Loki


            Storage
          ┌──────┴──────┐
          │             │
         NAS           SAN
          │
         NFS
          │
     ┌──────┴──────┐
     │             │
   Grafana        Loki
```

But I would not put Prometheus TSDB on NFS just because NFS is available. Prometheus has a write-heavy TSDB workload, so storage design deserves separate consideration.
One final point: the Loki/Alloy setup above is intentionally a lab configuration. Grafana's current documentation recommends more production-oriented deployment methods for Loki, and the simple single-binary configuration is appropriate for evaluation/testing rather than being the architecture I'd use for a large production logging platform. Grafana Labs
If you give me your actual Nomad topology (e.g. 3 Nomad servers + 3 Nomad clients, IPs/interfaces, and whether Consul is already installed), I can adapt these jobs to your exact cluster rather than leaving dc1, DNS names, storage paths, and networking as placeholders.
