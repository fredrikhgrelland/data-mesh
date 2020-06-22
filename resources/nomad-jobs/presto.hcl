job "presto" {
  type = "service"
  datacenters = ["dc1"]

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "12m"
    progress_deadline = "15m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
    stagger           = "30s"
  }
  group "standalone" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "presto"
      port = 8080
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "hive-metastore"
              local_bind_port  = 9083
            }
            upstreams {
              destination_name = "minio"
              local_bind_port  = 9000
            }
          }
        }
      }
      check {
        task     = "server"
        name     = "presto-hive-availability"
        type     = "script"
        command  = "presto"
        args     = ["--execute", "SHOW TABLES IN hive.default"]
        interval = "30s"
        timeout  = "15s"
      }
      check {
        expose   = true
        name     = "presto-info"
        type     = "http"
        path     = "/v1/info"
        interval = "10s"
        timeout  = "2s"
      }
      check {
        expose   = true
        name     = "presto-node"
        type     = "http"
        path     = "/v1/node"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "waitfor-hive-metastore" {
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
          {{- service "hive-metastore" | toJSON -}}
        EOH
      }
    }

    task "waitfor-minio" {
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
          {{- service "minio" | toJSON -}}
        EOH
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "prestosql/presto:333"
        volumes = [
          "local/presto/config.properties:/lib/presto/default/etc/config.properties",
          "local/presto/catalog/hive.properties:/lib/presto/default/etc/catalog/hive.properties",
        ]
      }
      template {
        data = <<EOH
          MINIO_ACCESS_KEY = "minioadmin"
          MINIO_SECRET_KEY = "minioadmin"
          EOH
        destination = "secrets/.env"
        env         = true
      }
// NB! If credentials set as env variable, during spin up of this container it could be sort of race condition and query `SELECT * FROM hive.default.iris;`
//     could end up with exception: The AWS Access Key Id you provided does not exist in our records.
//     Looks like, slow render of env variables (when one template depends on other template). Maybe because, all runs on local machine
      template {
        destination = "/local/presto/catalog/hive.properties"
        data = <<EOH
connector.name=hive-hadoop2
hive.metastore.uri=thrift://{{ env "NOMAD_UPSTREAM_ADDR_hive-metastore" }}
hive.metastore-timeout=1m
hive.s3.aws-access-key=minioadmin
hive.s3.aws-secret-key=minioadmin
#hive.s3.aws-access-key={{ env "MINIO_ACCESS_KEY" }}
#hive.s3.aws-secret-key={{ env "MINIO_SECRET_KEY" }}
#hive.s3.aws-access-key=$$MINIO_ACCESS_KEY
#hive.s3.aws-secret-key=$$MINIO_SECRET_KEY
hive.s3.endpoint=http://{{ env "NOMAD_UPSTREAM_ADDR_minio" }}
hive.s3.path-style-access=true
hive.s3.ssl.enabled=false
hive.s3.socket-timeout=15m
EOH
      }
      template {
        destination   = "local/presto/config.properties"
        data = <<EOH
node-scheduler.include-coordinator=true
http-server.http.port=8080
discovery-server.enabled=true
discovery.uri=http://127.0.0.1:8080
EOH
      }
      resources {
        memory = 2048
      }
    }
  }
}