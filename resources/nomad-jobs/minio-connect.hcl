job "minio" {
  type = "service"
  datacenters = ["dc1"]

  group "s3" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "minio"
      port = 9000
      # https://docs.min.io/docs/minio-monitoring-guide.html
      check {
        expose   = true
        name     = "minio-live"
        type     = "http"
        path     = "/minio/health/live"
        interval = "10s"
        timeout  = "2s"
      }
      check {
        expose   = true
        name     = "minio-ready"
        type     = "http"
        path     = "/minio/health/ready"
        interval = "15s"
        timeout  = "4s"
      }
      connect {
        sidecar_service {}
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "minio/minio:latest"
        memory_hard_limit = 2048
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