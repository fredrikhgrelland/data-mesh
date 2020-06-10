job "hue" {
  type        = "service"
  datacenters = ["dc1"]

  group "server" {
    count = 1

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "10m"
      progress_deadline = "12m"
      auto_revert       = true
      auto_promote      = true
      canary            = 1
      stagger           = "30s"
    }

    network {
      mode = "bridge"
    }

    service {
      name = "hue-server"
      port = 8888
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "hue-database"
              local_bind_port  = 5432
            }
            upstreams {
              destination_name = "presto"
              local_bind_port  = 8080
            }
          }
        }
      }
//      check {
//        expose   = true
//        name     = "hue-http-ui-ok"
//        type     = "http"
//        # does redirect to /hue/accounts/login?next=/
//        path     = "/"
//        interval = "10s"
//        timeout  = "2s"
//      }
    }

    task "waitfor-presto" {
      restart {
        attempts = 100
        delay    = "5s"
      }
      lifecycle {
        hook = "prestart"
      }
      driver = "docker"
      resources {
        memory = 32
      }
      config {
        image = "consul:latest"
        entrypoint = ["/bin/sh"]
        args = ["-c", "jq </local/service.json -e '.[].Status|select(. == \"passing\")'"]
        volumes = ["tmp/service.json:/local/service.json" ]
      }
      template {
        destination = "tmp/service.json"
        data = <<EOH
          {{- service "presto" | toJSON -}}
        EOH
      }
    }
    task "waitfor-database" {
      restart {
        attempts = 100
        delay    = "5s"
      }
      lifecycle {
        hook = "prestart"
      }
      driver = "docker"
      resources {
        memory = 32
      }
      config {
        image = "consul:latest"
        entrypoint = ["/bin/sh"]
        args = ["-c", "jq </local/service.json -e '.[].Status|select(. == \"passing\")'"]
        volumes = ["tmp/service.json:/local/service.json" ]
      }
      template {
        destination = "tmp/service.json"
        data = <<EOH
          {{- service "hue-database" | toJSON -}}
        EOH
      }
    }

    task "hueserver" {
      driver = "docker"

      config {
        image = "zhenik/hue:latest"
        volumes = [
          "local/hue-override.ini:/usr/share/hue/desktop/conf/hue-overrides.ini"
        ]
      }

      resources {
        cpu    = 200
        memory = 2048
      }

      logs {
        max_files     = 10
        max_file_size = 2
      }

      template {
        destination = "local/hue-override.ini"
        data = <<EOH
# Lightweight Hue configuration file
# ==================================
[desktop]
  secret_key=kasdlfjknasdfl3hbaksk3bwkasdfkasdfba23asdf
  http_host=0.0.0.0
  http_port=8888
  time_zone=Europe/Copenhagen
  django_debug_mode=false
  http_500_debug_mode=false
  app_blacklist=search,hbase,impala,jobbrowser,jobsub,pig,security,spark,sqoop,zookeeper
  [[database]]
    engine=postgresql_psycopg2
    host=localhost
    port=5432
    user=hue
    password=hue
    name=hue
 [notebook]
  [[interpreters]]
    [[[presto]]]
      name=Presto SQL
      interface=presto
      options='{"url": "jdbc:presto://localhost:8080/hive/default", "driver": "io.prestosql.jdbc.PrestoDriver", "user": "", "password": ""}'
[dashboard]
  has_sql_enabled=true
EOH
      }

    }
  }


  group "database" {
    count = 1

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
      canary            = 1
      stagger           = "30s"
    }

    service {
      name = "hue-database"
      port = 5432

      check {
        type     = "script"
        task     = "postgresql"
        command  = "/usr/local/bin/pg_isready"
        args     = ["-U", "hue"]
        interval = "5s"
        timeout  = "2s"
      }

      connect {
        sidecar_service {}
      }
    }

    network {
      mode = "bridge"
    }

    ephemeral_disk {
      migrate = true
      size    = 100
      sticky  = true
    }

    task "postgresql" {
      driver = "docker"

      env {
        POSTGRES_DB       = "hue"
        POSTGRES_USER     = "hue"
        POSTGRES_PASSWORD = "hue"
        PGDATA            = "/var/lib/postgresql/data"
      }

      config {
        image = "postgres:12-alpine"
      }
      resources {
        cpu    = 200
        memory = 256
      }
      logs {
        max_files     = 10
        max_file_size = 2
      }
    }
  }
}
