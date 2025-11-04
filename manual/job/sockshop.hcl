job "sockshop" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  update {
    stagger      = "10s"
    max_parallel = 1
  }

  #######################
  # USER SERVICE GROUP  #
  #######################
  group "user" {
    count = 1

    network {
      port "http" {}
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    # --- user app ---
    task "user" {
      driver = "docker"

      env {
        HATEAOS = "user.service.consul"
      }

      config {
        image    = "weaveworksdemos/user:master-5e88df65"
        hostname = "user.service.consul"
        # network_mode = "sockshop"
        ports = ["http"]
      }

      vault {
        policies = ["sockshop-read"]
      }

      template {
        data = <<EOH
MONGO_PASS="{{with secret "secret/sockshop/databases/userdb" }}{{.Data.pwd}}{{end}}"
EOH
        destination = "secrets/user_db.env"
        env         = true
      }

      service {
        name = "user"
        tags = ["app", "user"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }

    # --- user db ---
    task "user-db" {
      driver = "docker"

      config {
        image    = "weaveworksdemos/user-db:master-5e88df65"
        hostname = "user-db.service.consul"
        # network_mode = "sockshop"
      }

      vault {
        policies = ["sockshop-read"]
      }

      template {
        data = <<EOH
MONGO_PASS="{{with secret "secret/sockshop/databases/userdb" }}{{.Data.pwd}}{{end}}"
EOH
        destination = "secrets/user_db.env"
        env         = true
      }

      service {
        name = "user-db"
        tags = ["db", "user", "user-db"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 96
      }
    }
  }

  ###########################
  # CATALOGUE SERVICE GROUP #
  ###########################
  group "catalogue" {
    count = 1

    network {
      port "http" {}
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "catalogue" {
      driver = "docker"

      config {
        image    = "weaveworksdemos/catalogue:0.3.5"
        hostname = "catalogue.service.consul"
        # network_mode = "sockshop"
        ports = ["http"]
      }

      service {
        name = "catalogue"
        tags = ["app", "catalogue"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "cataloguedb" {
      driver = "docker"

      config {
        image    = "weaveworksdemos/catalogue-db:0.3.5"
        hostname = "catalogue-db.service.consul"
        # network_mode = "sockshop"
      }

      vault {
        policies = ["sockshop-read"]
      }

      template {
        data = <<EOH
MYSQL_ROOT_PASSWORD="{{with secret "secret/sockshop/databases/cataloguedb" }}{{.Data.pwd}}{{end}}"
EOH
        destination = "secrets/mysql_root_pwd.env"
        env         = true
      }

      env {
        MYSQL_DATABASE            = "socksdb"
        MYSQL_ALLOW_EMPTY_PASSWORD = "false"
      }

      service {
        name = "catalogue-db"
        tags = ["db", "catalogue", "catalogue-db"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }

  #######################
  # CARTS SERVICE GROUP #
  #######################
  group "carts" {
    count = 1

    network {
      port "http" {}
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "carts" {
      driver = "docker"

      env {
        db = "carts-db.service.consul"
      }

      config {
        image    = "weaveworksdemos/carts:0.4.8"
        hostname = "carts.service.consul"
        # network_mode = "sockshop"
        ports = ["http"]
      }

      service {
        name = "carts"
        tags = ["app", "carts"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 1024
      }
    }

    task "cartdb" {
      driver = "docker"

      config {
        image    = "mongo:3.4.3"
        hostname = "carts-db.service.consul"
        # network_mode = "sockshop"
      }

      service {
        name = "carts-db"
        tags = ["db", "carts", "carts-db"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  ########################
  # ORDERS SERVICE GROUP #
  ########################
  group "orders" {
    count = 1

    network {
      port "http" {}
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "orders" {
      driver = "docker"

      env {
        db     = "orders-db.service.consul"
        domain = "service.consul"
      }

      config {
        image    = "weaveworksdemos/orders:0.4.7"
        hostname = "orders.service.consul"
        # network_mode = "sockshop"
        ports = ["http"]
      }

      service {
        name = "orders"
        tags = ["app", "orders"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 1024
      }
    }

    task "ordersdb" {
      driver = "docker"

      config {
        image    = "mongo:3.4.3"
        hostname = "orders-db.service.consul"
        # network_mode = "sockshop"
      }

      service {
        name = "orders-db"
        tags = ["db", "orders", "orders-db"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }

  ########################
  # PAYMENT SERVICE GROUP#
  ########################
  group "payment" {
    count = 1

    network {
      port "http" {}
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "payment" {
      driver = "docker"

      config {
        image    = "weaveworksdemos/payment:0.4.3"
        hostname = "payment"
        # network_mode = "sockshop"
        ports = ["http"]
      }

      service {
        name = "payment"
        tags = ["app", "payment"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 16
      }
    }
  }

  ########################
  # BACKOFFICE GROUP     #
  ########################
  group "backoffice" {
    count = 1

    network {
      port "http" {
        static = 5672
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "rabbitmq" {
      driver = "docker"

      config {
        image    = "rabbitmq:3.6.8"
        hostname = "rabbitmq.service.consul"
        # network_mode = "sockshop"
      }

      service {
        name = "rabbitmq"
        tags = ["message-broker", "rabbitmq"]
      }

      resources {
        cpu    = 100
        memory = 160
      }
    }

    task "shipping" {
      driver = "docker"

      env {
        spring_rabbitmq_host = "${NOMAD_IP_http}"
      }

      config {
        image    = "weaveworksdemos/shipping:0.4.8"
        hostname = "shipping.service.consul"
        # network_mode = "sockshop"
        ports = ["http"]
      }

      service {
        name = "shipping"
        tags = ["app", "shipping"]
        port = "http"
      }

      resources {
        cpu    = 100
        memory = 1024
      }
    }

    task "queue-master" {
      driver = "java"

      config {
        jar_path    = "local/queue-master.jar"
        jvm_options = ["-Xms512m", "-Xmx512m"]
        args        = ["--port=8099", "--spring.rabbitmq.host=${attr.unique.network.ip-address}"]
      }

      artifact {
        source = "https://s3.amazonaws.com/nomad-consul-microservices-demo/queue-master.jar"
      }

      service {
        name = "queue-master"
        tags = ["app", "queue-master"]
      }

      resources {
        cpu    = 100
        memory = 1024
      }
    }
  }
}
