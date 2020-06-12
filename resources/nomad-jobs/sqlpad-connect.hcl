job "sqlpad" {
  type = "service"
  datacenters = ["dc1"]

  group "sqlpad" {
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
      port "dashboard" {
        to = 3000
      }
    }

    service {
      name = "sqlpad-server"
      port = 3000
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "presto"
              local_bind_port = 8080
            }
          }
        }
      }
    }

    task "sqlpad-setup" {
      driver = "docker"
      config {
        image = "sqlpad/sqlpad:4.4.0"
      }
      resources {
        cpu ="400"
        memory = "512"
      }
    }
  }
}