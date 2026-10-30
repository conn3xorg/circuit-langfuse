variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}


variable "langfuse_version" {
  type        = string
  default     = "4.72.0"
  description = "Tag of the docker.io/langfuse/langfuse and docker.io/langfuse/langfuse-worker images, such as \"4.72.0\". Change web_image_digest and worker_image_digest with it."

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.langfuse_version))
    error_message = "langfuse_version must be an image tag, such as \"4.72.0\"."
  }
}

variable "web_image_digest" {
  type        = string
  default     = "sha256:c311fd9db4b69f6514fdcb1b86a2a105d5a4ed51fbf0ded033ff2722459c804a"
  description = "Digest of docker.io/langfuse/langfuse for langfuse_version. Podman pulls by the digest, so a tag that moves upstream can't change what runs."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.web_image_digest))
    error_message = "web_image_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "worker_image_digest" {
  type        = string
  default     = "sha256:aa1724b989a00f1e4ca9930709202489c73deaaf2f1116bbd3d71c77edb8fedb"
  description = "Digest of docker.io/langfuse/langfuse-worker for langfuse_version."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.worker_image_digest))
    error_message = "worker_image_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "clickhouse_version" {
  type        = string
  default     = "26.8.36.3"
  description = "Tag of the docker.io/clickhouse/clickhouse-server image, such as \"26.8.36.3\". Langfuse 4 needs ClickHouse 25.12 or later. Change clickhouse_image_digest with it."

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.clickhouse_version))
    error_message = "clickhouse_version must be an image tag, such as \"26.8.36.3\"."
  }
}

variable "clickhouse_image_digest" {
  type        = string
  default     = "sha256:d426d2f612e1e189c90f9a3f8dcd85a03c6851273833817a296bb327e63aa7a7"
  description = "Digest of docker.io/clickhouse/clickhouse-server for clickhouse_version."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.clickhouse_image_digest))
    error_message = "clickhouse_image_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "minio_image_digest" {
  type        = string
  default     = "sha256:e234321fd3abff7fb968b0674056e883b702aa1ad93a0d4d795cb6c21fa46407"
  description = "Digest of cgr.dev/chainguard/minio:latest to run. Chainguard's free tier publishes only the latest tag, so the digest is the pin."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.minio_image_digest))
    error_message = "minio_image_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "public_url" {
  type        = string
  description = "The address people and SDKs reach Langfuse at, such as \"https://langfuse.example.com\". Langfuse sets it as NEXTAUTH_URL and builds sign-in redirects and links from it."

  validation {
    condition     = can(regex("^https?://[^\\s/]+(/[^\\s]*)?$", var.public_url))
    error_message = "public_url must be an http or https URL, such as \"https://langfuse.example.com\"."
  }
}

variable "database_url" {
  type        = string
  ephemeral   = true
  sensitive   = true
  description = "PostgreSQL connection URI, such as \"postgresql://langfuse:PASSWORD@127.0.0.1:5432/langfuse\". It reaches the host in a root-only file and never the plan or state."

  validation {
    condition     = can(regex("^postgres(ql)?://", var.database_url)) && !strcontains(var.database_url, "\n")
    error_message = "database_url must be a postgres:// or postgresql:// URI on one line."
  }
}

variable "redis_url" {
  type        = string
  ephemeral   = true
  sensitive   = true
  description = "Redis or Valkey URL, such as \"redis://:PASSWORD@127.0.0.1:6379\". The server needs maxmemory-policy noeviction. It reaches the host in a root-only file and never the plan or state."

  validation {
    condition     = can(regex("^rediss?://", var.redis_url)) && !strcontains(var.redis_url, "\n")
    error_message = "redis_url must be a redis:// or rediss:// URL on one line."
  }
}

variable "organization" {
  type        = string
  default     = "default"
  description = "ID and name of the organization Langfuse creates on its first start, such as \"homelab\"."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.organization))
    error_message = "organization must be lowercase letters, digits and hyphens, such as \"homelab\"."
  }
}

variable "project" {
  type        = string
  default     = "default"
  description = "ID and name of the project Langfuse creates in that organization, such as \"chatbot\"."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.project))
    error_message = "project must be lowercase letters, digits and hyphens, such as \"chatbot\"."
  }
}

variable "admin_email" {
  type        = string
  description = "Email address of the first user, who owns the organization and signs in with admin_password."

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+$", var.admin_email))
    error_message = "admin_email must be an email address, such as \"you@example.com\"."
  }
}

variable "admin_password" {
  type        = string
  ephemeral   = true
  sensitive   = true
  description = "Password of the first user. It reaches the host in a root-only file and never the plan or state. Langfuse sets it only when it creates the user."

  validation {
    condition     = length(var.admin_password) >= 8 && !strcontains(var.admin_password, "\n")
    error_message = "admin_password must be at least 8 characters on one line."
  }
}

variable "project_public_key" {
  type        = string
  default     = null
  ephemeral   = true
  sensitive   = true
  description = "Public API key Langfuse gives the project, such as \"pk-lf-...\". Set it with project_secret_key, or leave both null and create keys in the web interface."

  validation {
    condition     = var.project_public_key == null || can(regex("^[A-Za-z0-9_-]{8,}$", var.project_public_key))
    error_message = "project_public_key must be at least 8 letters, digits, hyphens or underscores, such as \"pk-lf-...\"."
  }
}

variable "project_secret_key" {
  type        = string
  default     = null
  ephemeral   = true
  sensitive   = true
  description = "Secret API key that goes with project_public_key, such as \"sk-lf-...\"."

  validation {
    condition     = var.project_secret_key == null || can(regex("^[A-Za-z0-9_-]{8,}$", var.project_secret_key))
    error_message = "project_secret_key must be at least 8 letters, digits, hyphens or underscores, such as \"sk-lf-...\"."
  }

  validation {
    condition     = (var.project_secret_key == null) == (var.project_public_key == null)
    error_message = "Set project_public_key and project_secret_key together, or neither."
  }
}

variable "signup" {
  type        = bool
  default     = false
  description = "Let anyone who can reach Langfuse create an account. Off by default, so only the first user and the people they invite get in."
}

variable "listen_address" {
  type        = string
  default     = "127.0.0.1"
  description = "Address the Langfuse web server listens on. The default keeps it on the host for a reverse proxy in front; \"0.0.0.0\" listens on every address."

  validation {
    condition     = can(cidrhost("${var.listen_address}/${strcontains(var.listen_address, ":") ? 128 : 32}", 0))
    error_message = "listen_address must be an IPv4 or IPv6 address, such as \"127.0.0.1\"."
  }
}

variable "port" {
  type        = number
  default     = 3000
  description = "Port the Langfuse web server listens on."

  validation {
    condition     = var.port >= 1 && var.port <= 65535 && floor(var.port) == var.port
    error_message = "port must be a whole number from 1 to 65535."
  }
}

variable "min_memory_mb" {
  type        = number
  default     = 3500
  description = "Memory, in MiB, a host needs before the circuit configures it. The whole stack wants 4 GB; a 4 GB host reports a little less."

  validation {
    condition     = var.min_memory_mb >= 0
    error_message = "min_memory_mb can't be negative."
  }
}

variable "environment" {
  type        = map(string)
  default     = {}
  ephemeral   = true
  sensitive   = true
  nullable    = false
  description = "More of Langfuse's environment variables for the web and worker containers, such as { SMTP_CONNECTION_URL = \"smtps://...\", EMAIL_FROM_ADDRESS = \"langfuse@example.com\" }. They go in root-only files and never reach the plan or state."

  validation {
    condition     = alltrue([for k, v in var.environment : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k)) && !strcontains(v, "\n")])
    error_message = "environment maps variable names, such as SMTP_CONNECTION_URL, to values on one line."
  }

  validation {
    condition     = length([for k in keys(var.environment) : k if contains(["DATABASE_URL", "REDIS_CONNECTION_STRING", "NEXTAUTH_URL", "NEXTAUTH_SECRET", "SALT", "ENCRYPTION_KEY", "HOSTNAME", "PORT", "TELEMETRY_ENABLED", "AUTH_DISABLE_SIGNUP"], k) || startswith(k, "CLICKHOUSE_") || startswith(k, "LANGFUSE_INIT_") || startswith(k, "LANGFUSE_S3_EVENT_UPLOAD_") || startswith(k, "LANGFUSE_S3_MEDIA_UPLOAD_")]) == 0
    error_message = "Variables the circuit sets itself aren't allowed in environment: the connection strings, URLs, keys, listen settings, telemetry, signup, CLICKHOUSE_*, LANGFUSE_INIT_* and the S3 event and media upload settings."
  }
}
