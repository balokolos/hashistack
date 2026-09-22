# Observability Connect Runbook

This document records the root causes and fixes applied to the Nomad observability stack.

## Current topology

- Traefik discovers services through the Consul Catalog provider.
- Grafana uses a Consul Connect sidecar.
- Grafana reaches Prometheus through `http://localhost:9090`.
- Grafana reaches Loki through `http://localhost:3100`.
- Alloy reaches Loki through `http://localhost:3100`.
- Prometheus discovers node-exporter through Consul service discovery.
- Loki, Prometheus, and Alloy use bridge networking because Connect sidecars require bridge or CNI networking.

## Grafana and Traefik

### Root cause

The Grafana service had Traefik tags, and Nomad copied those tags to the Grafana Connect sidecar. Traefik therefore discovered two services with the same router name:

- `grafana`
- `grafana-sidecar-proxy`

Traefik reported `Router defined multiple times with different configurations` and did not create a usable route.

### Fix

In `grafana.nomad`, disable Traefik discovery for the sidecar:

```hcl
connect {
  sidecar_service {
    tags = ["traefik.enable=false"]
  }
}
```

In `traefik.nomad`, enable Consul Connect awareness:

```text
--providers.consulcatalog.connectaware=true
```

### Verification

```bash
curl -s http://127.0.0.1:8080/api/http/routers
curl -skI -H 'Host: grafana.balokolos.com' https://127.0.0.1/
```

Expected result: the Grafana router is enabled and HTTPS returns `302 /login`.

## Grafana and Prometheus

### Root cause

Grafana had a Connect upstream for Prometheus, but Prometheus did not have a Connect sidecar. Grafana's request to `localhost:9090` was reset because there was no mesh destination.

After adding the sidecar, Prometheus still used a dynamic bridge port. The Connect proxy then targeted the host-mapped port instead of Prometheus's local application port.

### Fix

In `prometheus.nomad`:

1. Switch the group to bridge networking.
2. Add a Prometheus Connect sidecar.
3. Keep the application port static at `9090`.
4. Exclude the Prometheus sidecar from Traefik.

```hcl
network {
  mode = "bridge"

  port "http" {
    static = 9090
    to     = 9090
  }
}

service {
  name     = "prometheus"
  port     = "http"
  provider = "consul"

  connect {
    sidecar_service {
      tags = ["traefik.enable=false"]
    }
  }
}
```

Grafana's upstream remains:

```hcl
upstreams {
  destination_name = "prometheus"
  local_bind_port  = 9090
}
```

### Verification

From the Grafana allocation:

```bash
nomad alloc exec -task grafana <grafana-allocation> \\
  wget -qO- --post-data='query=up' \\
  http://127.0.0.1:9090/api/v1/query
```

Expected result: Prometheus returns a successful vector response.

## Node-exporter and Prometheus

### Root cause

Prometheus runs in bridge networking, but its Consul service discovery configuration used:

```yaml
server: "127.0.0.1:8500"
```

Inside the Prometheus container, `127.0.0.1` is the container itself, not the host Consul agent. Prometheus therefore discovered no node-exporter targets.

### Fix

Point Consul service discovery to the host Consul agent:

```yaml
consul_sd_configs:
  - server: "172.17.244.60:8500"
    datacenter: "dc1"
```

This address is specific to the current lab host and should be replaced with the correct reachable Consul-agent address when the environment changes.

### Verification

```bash
curl -s http://127.0.0.1:9090/api/v1/targets
curl -sG http://127.0.0.1:9090/api/v1/query \\
  --data-urlencode 'query=up{service="node-exporter"}'
```

Expected result:

```text
Target: http://172.17.244.60:9100/metrics
Health: up
up{service="node-exporter"} = 1
```

## Grafana and Loki

### Root cause

Grafana had no Loki Connect upstream, and Loki had no Connect sidecar. Loki also used a dynamic application port, which can cause the Connect proxy to target the wrong local port.

### Fix

In `loki.nomad`:

- Use bridge networking.
- Keep Loki application port `3100` static.
- Add a Connect sidecar.
- Disable Traefik discovery for the sidecar.

In `grafana.nomad`, add:

```hcl
upstreams {
  destination_name = "loki"
  local_bind_port  = 3100
}
```

Configure the Grafana Loki datasource as:

```text
http://localhost:3100
```

### Verification

```bash
nomad alloc exec -task grafana <grafana-allocation> \\
  wget -qO- http://127.0.0.1:3100/ready

nomad alloc exec -task grafana <grafana-allocation> \\
  wget -qO- http://127.0.0.1:3100/loki/api/v1/labels
```

Expected result: Loki returns `ready` and a successful API response.

## Alloy and Loki

### Root cause

Alloy originally used host networking and sent logs directly to:

```text
http://loki.service.consul:3100/loki/api/v1/push
```

That bypassed the Loki Connect sidecar and did not provide a stable mesh-local destination.

### Fix

In `alloy.nomad`:

1. Switch Alloy to bridge networking.
2. Map host port `12345` to container port `12345`.
3. Register Alloy as a Consul service.
4. Add an Alloy Connect sidecar with a Loki upstream on local port `3100`.
5. Send Alloy logs to `localhost:3100`.
6. Exclude the Alloy sidecar from Traefik discovery.

```hcl
network {
  mode = "bridge"

  port "http" {
    static = 12345
    to     = 12345
  }
}
```

Alloy endpoint:

```text
http://localhost:3100/loki/api/v1/push
```

### Verification

```bash
curl -s http://127.0.0.1:12345/-/ready
consul intention check alloy loki
curl -sG http://127.0.0.1:3100/loki/api/v1/query_range \\
  --data-urlencode 'query={job="docker"}' \\
  --data-urlencode 'limit=1'
```

Expected result: Alloy is ready, the intention is allowed, and Loki returns at least one Docker log stream.

## Deployment checklist

Validate each changed job before deployment:

```bash
nomad job validate traefik.nomad
nomad job validate grafana.nomad
nomad job validate prometheus.nomad
nomad job validate loki.nomad
nomad job validate alloy.nomad
```

For Connect-enabled jobs:

- Use `bridge` or `cni/*` networking.
- Keep the application port static when the sidecar must forward to a local application port.
- Add a Connect sidecar to both the caller and destination services.
- Add the required Consul intention.
- Disable Traefik discovery on Connect sidecars.
- Use the sidecar upstream's local bind address and port from the caller application.

## Nomad and Docker prerequisites

### Host-volume permission denied

If a task cannot write to its mounted data directory, the host volume exists but
the container user does not have write permission. For a lab environment, make
the monitoring data directories writable:

```bash
sudo mkdir -p /opt/monitoring/{prometheus,loki,grafana,alloy}/data
sudo chmod 777 /opt/monitoring/{prometheus,loki,grafana,alloy}/data
```

`chmod 777` is suitable only for a disposable lab. For a production setup,
prefer ownership and permissions matching the UID/GID used by each container.

The directories must also be declared as Nomad client host volumes:

```hcl
client {
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
```

Restart Nomad after changing the client configuration:

```bash
sudo systemctl restart nomad
nomad node status
```

### Docker socket and Nomad Docker plugin

Alloy reads Docker container logs through `/var/run/docker.sock`. Nomad's
Docker driver must allow Docker volume mounts for this bind mount to work.
Add the Docker plugin configuration to `nomad.hcl`:

```hcl
plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}
```

The Alloy job mounts the socket into the task:

```hcl
config {
  volumes = [
    "/var/run/docker.sock:/var/run/docker.sock"
  ]
}
```

Make sure the socket exists and restart Nomad after enabling the plugin:

```bash
ls -l /var/run/docker.sock
sudo systemctl restart nomad
nomad node status
```

If Alloy cannot read the socket, check the allocation logs:

```bash
nomad alloc logs <alloy-allocation> alloy
```
