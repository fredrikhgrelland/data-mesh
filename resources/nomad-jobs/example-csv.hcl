job "example-csv" {
  type = "batch"
  datacenters = ["dc1"]

  group "test" {

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
      check {
        name = "hiveserver-available-via-beeline"
        type = "script"
        task = "beeline"
        command = "/bin/bash"
        # using `|| exit 2` becuase beeline does exit 1 if connection fails, which consul marks as warning, not error.
        args = ["-c", "beeline -u \"jdbc:hive2://localhost:10000/default;auth=noSasl\" -n hive -p hive -e \"SHOW DATABASES\" &> /tmp/output_show_databases.txt || exit 2"]
        interval = "60s"
        timeout = "25s"
      }
      check {
        name = "testdata-available-via-beeline"
        type = "script"
        task = "beeline"
        command = "/bin/bash"
        # needs to use '|| exit 2' because beeline returns 1 if table doesn't exist, which will be marked as
        # 'warning' in consul
        args = ["-c", "beeline -u \"jdbc:hive2://localhost:10000/default;auth=noSasl\" -n hive -p hive -e \"SELECT * FROM default.iris LIMIT 2\" &> /tmp/output_select_iris.txt || exit 2"]
        interval = "60s"
        timeout = "25s"
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
        destination = "secrets/.env"
        env         = true
        data        = <<EOH
CORE_CONF_fs_s3a_access_key = "minioadmin"
CORE_CONF_fs_s3a_secret_key = "minioadmin"
EOH
      }
    }

    task "waitfor-hive-server" {
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
          {{- service "hive-server" | toJSON -}}
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

    task "beeline" {
      driver = "docker"

      config {
        image = "fredrikhgrelland/hive:3.1.0"
        command = "hiveserver"
      }

      resources {
        cpu    = 200
        memory = 1024
      }
    }
  }


}
