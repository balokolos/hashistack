Step 1
https://medium.com/@keshrianjani20/nomad-and-consul-series-part-1-running-your-first-nomad-job-with-consul-integration-5fa4a6efd12e

install as hashicorp guide

issue: consul cannot start
why: cannot elect leader
solution:
    sudo nano /etc/consul.d/consul.hcl

    datacenter       = "dc1"
    data_dir         = "/opt/consul"
    bind_addr        = "127.0.0.1" # or your local IP
    client_addr      = "0.0.0.0"

    # Enable Server Mode & Single-Node Self-Bootstrap
    server           = true
    bootstrap_expect = 1

    ui_config {
    enabled = true
    }

    consul members

    consul operator raft list-peers

    consul catalog services

Problem: Dig result empty
issue: dns query not on stndard dns port 53
solution:
    server$ dig @127.0.0.1 -p 8600 SRV nginx.service.consul

Step 2: Mesh
Problem: cannot deploy job/job failed
Issue: CNI not installed
Solution:
    Step 1: Install CNI Plugins on the Nomad Client Node
    Log into the server running your Nomad client and run the following commands to download and extract the official CNI plugins:

    Bash
    # 1. Create the standard CNI binary directory
    sudo mkdir -p /opt/cni/bin

    # 2. Download the latest CNI plugins (v1.3.0+ contains CNI bridge > 0.4.0)
    wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz

    # 3. Extract the plugins into /opt/cni/bin
    sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.3.0.tgz
    Step 2: Verify Nomad Client Config
    By default, Nomad automatically looks for CNI plugins in /opt/cni/bin.

    If you extracted them somewhere else, make sure your Nomad client configuration file (e.g., /etc/nomad.d/nomad.hcl) explicitly sets the path in the client block:

    Terraform
    client {
    enabled  = true
    cni_path = "/opt/cni/bin"
    }
    Step 3: Restart Nomad Client
    Restart the Nomad client service so it can re-fingerprint the host system and detect the newly installed CNI plugins:

    Bash
    sudo systemctl restart nomad