job "presto" {
  type = "service"
  datacenters = ["dc1"]

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
      lifecycle {
        hook    = "prestart"
      }
      driver = "docker"
      config {
        image = "alioygur/wait-for:latest"
        args = [ "-it", "${NOMAD_UPSTREAM_ADDR_hive-metastore}", "-t", 120 ]
      }
    }

    task "waitfor-minio" {
      lifecycle {
        hook    = "prestart"
      }
      driver = "docker"
      config {
        image = "alioygur/wait-for:latest"
        args = [ "-it", "${NOMAD_UPSTREAM_ADDR_minio}", "-t", 120 ]
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
      template {
        destination = "/local/presto/catalog/hive.properties"
        data = <<EOH
connector.name=hive-hadoop2
hive.metastore.uri=thrift://{{ env "NOMAD_UPSTREAM_ADDR_hive-metastore" }}
hive.metastore-timeout=1m
hive.s3.aws-access-key=$${MINIO_ACCESS_KEY}
hive.s3.aws-secret-key=$${MINIO_SECRET_KEY}
hive.s3.endpoint=http://{{ env "NOMAD_UPSTREAM_ADDR_minio" }}
hive.s3.path-style-access=true
hive.s3.ssl.enabled=false
hive.s3.socket-timeout=1m
              EOH
      }
      template {
        destination   = "local/presto/config.properties"
        data = <<EOH
              coordinator=true
node.id={{ env "NOMAD_ALLOC_ID" }}
node.environment={{ env "NOMAD_JOB_NAME" | replaceAll "-" "_" }}
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