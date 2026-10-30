output "services" {
  description = "The systemd services that run the stack on each host."
  value       = ["langfuse-web.service", "langfuse-worker.service", "langfuse-clickhouse.service", "langfuse-minio.service"]
}

output "images" {
  description = "The images the hosts run, by service."
  value = {
    langfuse-web        = local.web_image
    langfuse-worker     = local.worker_image
    langfuse-clickhouse = local.clickhouse_image
    langfuse-minio      = local.minio_image
  }
}

output "keys_file" {
  description = "File on each host holding the generated NEXTAUTH_SECRET, SALT, ENCRYPTION_KEY and the ClickHouse and MinIO passwords. Back it up: without ENCRYPTION_KEY and SALT, the database's encrypted values and API keys are useless."
  value       = local.keys_file
}
