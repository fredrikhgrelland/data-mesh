job "hive" {
  type        = "service"
  datacenters = ["dc1"]

  group "server" {
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
      port = 10000

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
    }

    network {
      mode = "bridge"

      port "ui" {
        to = 10002
      }

    }

    task "server" {
      driver = "docker"

      config {
        image = "fredrikhgrelland/hive:3.1.0"
      }

      resources {
        cpu    = 200
        memory = 1024
      }

      logs {
        max_files     = 10
        max_file_size = 2
      }

      template {
        data = <<EOH
          SERVICE_PRECONDITION = "{{ env "NOMAD_UPSTREAM_ADDR_hive-metastore" }}"
          HIVE_SITE_CONF_hive_metastore_uris="thrift://{{ env "NOMAD_UPSTREAM_ADDR_hive-metastore" }}"
          HIVE_SITE_CONF_hive_execution_engine="mr"
          HIVE_SITE_CONF_hive_support_concurrency=false
          HIVE_SITE_CONF_hive_driver_parallel_compilation=true
          HIVE_SITE_CONF_hive_metastore_warehouse_dir="s3a://hive/warehouse"
          HIVE_SITE_CONF_hive_metastore_event_db_notification_api_auth=false
          HIVE_SITE_CONF_hive_server2_active_passive_ha_enable=true
          HIVE_SITE_CONF_hive_server2_enable_doAs=false
          HIVE_SITE_CONF_hive_server2_thrift_port=10000
          HIVE_SITE_CONF_hive_server2_thrift_bind_host="127.0.0.1"
          HIVE_SITE_CONF_hive_server2_authentication="NOSASL"
          CORE_CONF_fs_defaultFS = "s3a://default"
          CORE_CONF_fs_s3a_connection_ssl_enabled = false
          CORE_CONF_fs_s3a_endpoint = "http://{{ env "NOMAD_UPSTREAM_ADDR_minio" }}"
          CORE_CONF_fs_s3a_path_style_access = true
          EOH

        destination = "local/config.env"
        env         = true
      }

      template {
        data = <<EOH
          CORE_CONF_fs_s3a_access_key = "minioadmin"
          CORE_CONF_fs_s3a_secret_key = "minioadmin"
          EOH

        destination = "secrets/.env"
        env         = true
      }
    }
  }

  group "beeline" {
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
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "hive-server"
              local_bind_port  = 10000
            }
          }
        }
      }
    }

    network {
      mode = "bridge"
    }

    task "beeline-testdata" {
      driver = "docker"

      config {
        image = "fredrikhgrelland/hive:3.1.0"
        command = "tail -f /dev/null"
        #command = "beeline -u \"jdbc:hive2://localhost:10000/default;auth=noSasl\" -n hive -p hive -f local/testdata.sql"
      }

      resources {
        cpu    = 200
        memory = 512
      }

      logs {
        max_files     = 10
        max_file_size = 2
      }

      template {
        data = <<EOH
          SERVICE_PRECONDITION = "{{ env "NOMAD_UPSTREAM_ADDR_hive-server" }}"
          EOH

        destination = "local/config.env"
        env         = true
      }
      template {
        data = <<EOH
CREATE EXTERNAL TABLE iris (sepal_length DECIMAL, sepal_width DECIMAL,
petal_length DECIMAL, petal_width DECIMAL, species STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
LOCATION 's3a://hive/warehouse/iris/'
TBLPROPERTIES ("skip.header.line.count"="1");
EOH
        destination = "local/testdata.sql"
      }
    }
  }

  group "metastore" {
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
      port = 9083

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "hive-database"
              local_bind_port  = 5432
            }
            upstreams {
              destination_name = "minio"
              local_bind_port  = 9000
            }
          }
        }
      }
    }

    network {
      mode = "bridge"
    }

    task "server" {
      driver = "docker"

      config {
        image   = "fredrikhgrelland/hive:3.1.0"
        command = "hive --service metastore"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      logs {
        max_files     = 10
        max_file_size = 2
      }

      env {
        METASTORE = "true"
      }

      template {
        data = <<EOH
          SERVICE_PRECONDITION = "{{ env "NOMAD_UPSTREAM_ADDR_hive-database" }}"
          HIVE_SITE_CONF_javax_jdo_option_ConnectionURL="jdbc:postgresql://{{ env "NOMAD_UPSTREAM_ADDR_hive-database" }}/metastore"
          HIVE_SITE_CONF_javax_jdo_option_ConnectionDriverName="org.postgresql.Driver"
          HIVE_SITE_CONF_datanucleus_autoCreateSchema=false
          HIVE_SITE_CONF_hive_metastore_uris="thrift://127.0.0.1:9083"
          HIVE_SITE_CONF_hive_metastore_schema_verification=true
          HIVE_SITE_CONF_hive_execution_engine="mr"
          HIVE_SITE_CONF_hive_support_concurrency=false
          HIVE_SITE_CONF_hive_driver_parallel_compilation=true
          HIVE_SITE_CONF_hive_metastore_warehouse_dir="s3a://hive/warehouse"
          HIVE_SITE_CONF_hive_metastore_event_db_notification_api_auth=false

          CORE_CONF_fs_defaultFS = "s3a://default"
          CORE_CONF_fs_s3a_connection_ssl_enabled = false
          CORE_CONF_fs_s3a_endpoint = "http://{{ env "NOMAD_UPSTREAM_ADDR_minio" }}"
          CORE_CONF_fs_s3a_path_style_access = true
          EOH

        destination = "local/config.env"
        env         = true
      }

      template {
        data = <<EOH
          CORE_CONF_fs_s3a_access_key = "minioadmin"
          CORE_CONF_fs_s3a_secret_key = "minioadmin"
          HIVE_SITE_CONF_javax_jdo_option_ConnectionUserName="hive"
          HIVE_SITE_CONF_javax_jdo_option_ConnectionPassword="hive"
          EOH

        destination = "secrets/.env"
        env         = true
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
      port = 5432

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
        POSTGRES_USER     = "hive"
        POSTGRES_PASSWORD = "hive"
        PGDATA            = "/var/lib/postgresql/data"
      }

      config {
        image = "postgres:12-alpine"

        volumes = [
          "local/init.sql:/docker-entrypoint-initdb.d/init.sql",
        ]
      }

      template {
        data = <<EOH
          CREATE DATABASE metastore;
          GRANT ALL PRIVILEGES ON DATABASE metastore TO hive;
        EOH

        destination = "local/init.sql"
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
