provider "nomad" {
  address = "http://127.0.0.1:4646"
}

resource "nomad_job" "minio" {
  jobspec = file("${path.cwd}/../nomad-jobs/minio.hcl")
  detach = false
}
resource "nomad_job" "hive" {
  jobspec = file("${path.cwd}/../nomad-jobs/hive.hcl")
  detach = false
}
resource "nomad_job" "presto" {
  jobspec = file("${path.cwd}/../nomad-jobs/presto.hcl")
  detach = false
}
resource "nomad_job" "example-csv" {
  jobspec = file("${path.cwd}/../nomad-jobs/example-csv.hcl")
  detach = false
}
resource "nomad_job" "sqlpad" {
  jobspec = file("${path.cwd}/../nomad-jobs/sqlpad.hcl")
  detach = false
}
