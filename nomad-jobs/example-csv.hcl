job "example-csv" {
  type = "batch"
  datacenters = ["dc1"]

  group "test" {

    count = 1

    service {
      name = "testdata-csv"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "minio"
              local_bind_port  = 9000
            }
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

    # using minio client
    task "s3-file-upload" {
      driver = "docker"

      restart {
        interval = "30m"
        attempts = 5
        delay    = "45s"
        mode     = "fail"
      }

      config {
        image = "minio/mc:latest"
        volumes = [
          "local/tmp/iris.csv:/tmp/iris.csv",
        ]
        entrypoint = [
          "/bin/sh", "-c",
          "mc config host add myminio http://${NOMAD_UPSTREAM_ADDR_minio} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} && mc cp /tmp/iris.csv myminio/hive/warehouse/iris/iris.csv"
        ]
      }

      template {
        destination = "local/tmp/iris.csv"
        data        = <<EOH
sepal_length,sepal_width,petal_length,petal_width,species
5.1,3.5,1.4,0.2,setosa
4.9,3,1.4,0.2,berlin
3.7,3.2,1.3,0.2,oslo
4.6,3.1,1.5,0.2,lime
5,3.6,1.4,0.2,ololo
1.4,3.9,1.7,0.4,otava
4.6,3.4,1.4,0.3,setosa
EOH
      }

      template {
        destination = "secrets/.env"
        env         = true
        data        = <<EOH
MINIO_ACCESS_KEY = "minioadmin"
MINIO_SECRET_KEY = "minioadmin"
EOH
      }
    }

    # using remote beeline
    task "hiveserver-create-table" {

      driver = "docker"

      restart {
        interval = "30m"
        attempts = 5
        delay    = "45s"
        mode     = "fail"
      }
      // todo: extract beeline credentials (Using hive-site.xml to automatically connect to HiveServer2) -> https://cwiki.apache.org/confluence/display/Hive/HiveServer2+Clients
      config {
        image = "fredrikhgrelland/hive:3.1.0"
        command = "beeline -u \"jdbc:hive2://localhost:10000/default;auth=noSasl\" -n hive -p hive -f /tmp/create-table.hql"
        volumes = [
          "local/tmp/create-table.hql:/tmp/create-table.hql"
        ]
      }

      resources {
        cpu    = 200
        memory = 2048
      }

      template {
        destination = "local/tmp/create-table.hql"
        data        = <<EOH
CREATE EXTERNAL TABLE IF NOT EXISTS iris (sepal_length DECIMAL, sepal_width DECIMAL,
petal_length DECIMAL, petal_width DECIMAL, species STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
LOCATION 's3a://hive/warehouse/iris/'
TBLPROPERTIES ("skip.header.line.count"="1");
EOH
      }

      template {
        destination = "local/config.env"
        env         = true
        data        = <<EOH
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
      }

      template {
        destination = "secrets/.env"
        env         = true
        data        = <<EOH
CORE_CONF_fs_s3a_access_key = "minioadmin"
CORE_CONF_fs_s3a_secret_key = "minioadmin"
EOH
      }
    }
  }


}