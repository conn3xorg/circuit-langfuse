variable "port" {
  type    = number
  default = 2222
}

# Example passwords and keys only. Pass your own with -var or TF_VAR_ on a
# real host.
variable "db_password" {
  type      = string
  default   = "correct-horse-battery"
  ephemeral = true
  sensitive = true
}

variable "valkey_password" {
  type      = string
  default   = "staple-paper-clip"
  ephemeral = true
  sensitive = true
}

variable "admin_password" {
  type      = string
  default   = "tracing-paper-kite"
  ephemeral = true
  sensitive = true
}

variable "project_secret_key" {
  type      = string
  default   = "sk-lf-example-not-secret"
  ephemeral = true
  sensitive = true
}

locals {
  host = { box = "127.0.0.1" }
}

# PostgreSQL and Valkey on the same host, each listening only on localhost.
# Valkey's default maxmemory-policy, noeviction, is the one Langfuse needs.
module "postgres" {
  source = "github.com/conn3xorg/circuit-postgres?ref=v0.2.0"

  hosts                = local.host
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  users          = ["langfuse"]
  user_passwords = { langfuse = var.db_password }
  databases      = { langfuse = "langfuse" }
}

module "valkey" {
  source = "github.com/conn3xorg/circuit-valkey?ref=v0.1.0"

  hosts                = local.host
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  password = var.valkey_password
}

module "langfuse" {
  source = "../.."

  depends_on = [module.postgres, module.valkey]

  hosts                = local.host
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  public_url   = "http://localhost:3000"
  database_url = "postgresql://langfuse:${var.db_password}@127.0.0.1:5432/langfuse"
  redis_url    = "redis://:${var.valkey_password}@127.0.0.1:6379"

  organization       = "homelab"
  project            = "example"
  admin_email        = "admin@example.com"
  admin_password     = var.admin_password
  project_public_key = "pk-lf-example"
  project_secret_key = var.project_secret_key
}
