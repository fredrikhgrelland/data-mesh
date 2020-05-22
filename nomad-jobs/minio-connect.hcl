job "minio" {
  type = "service"
  datacenters = ["dc1"]

  group "s3" {
    count = 1

    network {
      mode = "bridge"
      port "healthchecklive" {
        to = -1
      }
      port "healthcheckready" {
        to = -1
      }
    }

    service {
      name = "minio"
      port = 9000
      # https://docs.min.io/docs/minio-monitoring-guide.html
      check {
        name     = "minio-live"
        type     = "http"
        port     = "healthchecklive"
        path     = "/minio/health/live"
        interval = "10s"
        timeout  = "2s"
      }
      check {
        name     = "minio-ready"
        type     = "http"
        port     = "healthcheckready"
        path     = "/minio/health/ready"
        interval = "15s"
        timeout  = "4s"
      }
      connect {
        sidecar_service {
          proxy {
            expose {
              path {
                path            = "/minio/health/live"
                protocol        = "http"
                local_path_port = 9000
                listener_port   = "healthchecklive"
              }
              path {
                path            = "/minio/health/ready"
                protocol        = "http"
                local_path_port = 9000
                listener_port   = "healthcheckready"
              }
            }
          }
        }
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "minio/minio:latest"
        args = [
          "server", "/local/data", "-address", "127.0.0.1:9000"
        ]
      }
      resources {
        cpu = 200
        memory = 1024
      }
    }
  }
}