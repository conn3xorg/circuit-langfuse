locals {
  web_image        = "docker.io/langfuse/langfuse:${var.langfuse_version}@${var.web_image_digest}"
  worker_image     = "docker.io/langfuse/langfuse-worker:${var.langfuse_version}@${var.worker_image_digest}"
  clickhouse_image = "docker.io/clickhouse/clickhouse-server:${var.clickhouse_version}@${var.clickhouse_image_digest}"
  minio_image      = "cgr.dev/chainguard/minio:latest@${var.minio_image_digest}"

  dir       = "/etc/langfuse"
  keys_file = "${local.dir}/keys.env"

  # ClickHouse and MinIO share the host's network with Langfuse, so their
  # ports are fixed and on loopback only. MinIO moves off 9000, which is
  # ClickHouse's native port, and off 9090, which Rocky Linux and RHEL
  # often give to Cockpit.
  s3_endpoint = "http://127.0.0.1:9002"

  # What the web and the worker both need, none of it secret. The secrets
  # come from keys.env and from circuit-podman's env file.
  common_env = {
    NEXTAUTH_URL                              = var.public_url
    TELEMETRY_ENABLED                         = "false"
    CLICKHOUSE_MIGRATION_URL                  = "clickhouse://127.0.0.1:9000"
    CLICKHOUSE_URL                            = "http://127.0.0.1:8123"
    CLICKHOUSE_USER                           = "langfuse"
    CLICKHOUSE_CLUSTER_ENABLED                = "false"
    LANGFUSE_S3_EVENT_UPLOAD_BUCKET           = "langfuse"
    LANGFUSE_S3_EVENT_UPLOAD_PREFIX           = "events/"
    LANGFUSE_S3_EVENT_UPLOAD_REGION           = "auto"
    LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT         = local.s3_endpoint
    LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID    = "langfuse"
    LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE = "true"
    LANGFUSE_S3_MEDIA_UPLOAD_BUCKET           = "langfuse"
    LANGFUSE_S3_MEDIA_UPLOAD_PREFIX           = "media/"
    LANGFUSE_S3_MEDIA_UPLOAD_REGION           = "auto"
    LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT         = local.s3_endpoint
    LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID    = "langfuse"
    LANGFUSE_S3_MEDIA_UPLOAD_FORCE_PATH_STYLE = "true"
  }

  # The image's own copy of this file listens on every address. This one
  # keeps ClickHouse on loopback and drops the MySQL, PostgreSQL and
  # interserver ports Langfuse doesn't use.
  clickhouse_config = <<-EOT
    <!-- Managed by Conn3x. -->
    <clickhouse>
        <listen_host>127.0.0.1</listen_host>
        <mysql_port remove="1"/>
        <postgresql_port remove="1"/>
        <interserver_http_port remove="1"/>
    </clickhouse>
  EOT
}

# Facts give each host's memory. ClickHouse, the two Langfuse processes,
# PostgreSQL and Valkey together want about 4 GB.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = self.memory_mb >= var.min_memory_mb
      error_message = "Host ${each.key} has ${self.memory_mb} MiB of memory. Langfuse with ClickHouse needs about 4 GB on one host. Set min_memory_mb lower to go ahead anyway."
    }
  }
}

# Every secret the stack makes for itself is generated on the host by the
# first apply and never passes through Conn3x, so it's in neither the plan
# nor state. ENCRYPTION_KEY encrypts what Langfuse stores, such as LLM API
# keys, and SALT hashes the project API keys, so creates keeps them from
# ever being replaced. ClickHouse and MinIO get only their own password.
circuit "keys" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "dir" {
    depends_on = [data.conn3x_host.facts]
    directory {
      path  = local.dir
      owner = "root"
      group = "root"
      mode  = "0700"
    }
  }

  # ENCRYPTION_KEY is 32 random bytes in hex, the form Langfuse requires.
  # The rest are hex too, so nothing needs escaping in a URL or env file.
  step "generate" {
    command {
      command = <<-EOT
        set -eu
        umask 077
        cd ${local.dir}
        hex() { head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'; }
        ch=$(hex 24)
        s3=$(hex 24)
        printf 'CLICKHOUSE_PASSWORD=%s\n' "$ch" > clickhouse.env
        printf 'MINIO_ROOT_PASSWORD=%s\n' "$s3" > minio.env
        {
          printf 'NEXTAUTH_SECRET=%s\n' "$(hex 32)"
          printf 'SALT=%s\n' "$(hex 32)"
          printf 'ENCRYPTION_KEY=%s\n' "$(hex 32)"
          printf 'CLICKHOUSE_PASSWORD=%s\n' "$ch"
          printf 'LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY=%s\n' "$s3"
          printf 'LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY=%s\n' "$s3"
        } > keys.env.new
        mv keys.env.new keys.env
      EOT
      creates = local.keys_file
    }
  }

  step "clickhouse_config" {
    file {
      path    = "${local.dir}/clickhouse.xml"
      content = local.clickhouse_config
      mode    = "0644"
    }
  }
}

# Four containers from official images, each a Quadlet unit on the host's
# network, so Langfuse reaches a PostgreSQL and Valkey that listen only on
# localhost, and nothing but the web server could ever face outward.
# ClickHouse and MinIO keep their data in named volumes.
module "podman" {
  source = "github.com/conn3xorg/circuit-podman?ref=v0.1.0"

  depends_on = [conn3x_command.keys__generate, conn3x_file.keys__clickhouse_config]

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  containers = {
    # User matches Langfuse's own compose file: the image's clickhouse user.
    langfuse-clickhouse = {
      image = local.clickhouse_image
      volumes = [
        "langfuse-clickhouse:/var/lib/clickhouse",
        "langfuse-clickhouse-logs:/var/log/clickhouse-server",
        "${local.dir}/clickhouse.xml:/etc/clickhouse-server/config.d/docker_related_config.xml:ro,Z",
      ]
      environment = {
        CLICKHOUSE_DB   = "default"
        CLICKHOUSE_USER = "langfuse"
      }
      extra = [
        "Network=host",
        "User=101:101",
        "Ulimit=nofile=262144:262144",
        "EnvironmentFile=${local.dir}/clickhouse.env",
      ]
    }

    # The bucket is a directory MinIO finds at start, as in Langfuse's own
    # compose file. The web console stays off.
    langfuse-minio = {
      image   = local.minio_image
      volumes = ["langfuse-minio:/data"]
      environment = {
        MINIO_ROOT_USER = "langfuse"
        MINIO_BROWSER   = "off"
      }
      extra = [
        "Network=host",
        "EnvironmentFile=${local.dir}/minio.env",
        "PodmanArgs=--entrypoint=sh",
        "Exec=-c \"mkdir -p /data/langfuse && exec minio server --address 127.0.0.1:9002 /data\"",
      ]
    }

    langfuse-worker = {
      image = local.worker_image
      environment = merge(local.common_env, {
        HOSTNAME = "127.0.0.1"
        PORT     = "3030"
      })
      extra = ["Network=host", "EnvironmentFile=${local.keys_file}"]
    }

    # LANGFUSE_INIT_* create the organization, project, API keys and first
    # user on the first start, and leave them alone after that.
    langfuse-web = {
      image = local.web_image
      environment = merge(local.common_env, {
        HOSTNAME                   = var.listen_address
        PORT                       = tostring(var.port)
        AUTH_DISABLE_SIGNUP        = tostring(!var.signup)
        LANGFUSE_INIT_ORG_ID       = var.organization
        LANGFUSE_INIT_ORG_NAME     = var.organization
        LANGFUSE_INIT_PROJECT_ID   = var.project
        LANGFUSE_INIT_PROJECT_NAME = var.project
        LANGFUSE_INIT_USER_EMAIL   = var.admin_email
      })
      extra = ["Network=host", "EnvironmentFile=${local.keys_file}"]
    }
  }
  secrets = {
    langfuse-worker = merge(var.environment, {
      DATABASE_URL            = var.database_url
      REDIS_CONNECTION_STRING = var.redis_url
    })
    langfuse-web = merge(var.environment, {
      DATABASE_URL                = var.database_url
      REDIS_CONNECTION_STRING     = var.redis_url
      LANGFUSE_INIT_USER_PASSWORD = var.admin_password
      }, var.project_public_key == null ? {} : {
      LANGFUSE_INIT_PROJECT_PUBLIC_KEY = var.project_public_key
      LANGFUSE_INIT_PROJECT_SECRET_KEY = var.project_secret_key
    })
  }
}

circuit "langfuse" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # The web container runs the PostgreSQL and ClickHouse migrations before
  # it opens the port, which on a first start comes after pulling about
  # 2 GB of images.
  step "ready" {
    depends_on = [module.podman]
    wait_for {
      port    = var.port
      timeout = "15m"
    }
  }
}
