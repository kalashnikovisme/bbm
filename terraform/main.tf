########################################
# main.tf — DigitalOcean droplet runner
########################################

terraform {
  required_version = ">= 1.2"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

########################################
# Provider
########################################

provider "digitalocean" {
  token = var.do_token
}

########################################
# Locals & Data Sources
########################################

locals {
  ssh_key_name        = trimspace(var.ssh_key_name)
  ssh_key_fingerprint = trimspace(var.ssh_fingerprint)

  use_fingerprint = local.ssh_key_fingerprint != ""
  use_name        = !local.use_fingerprint && local.ssh_key_name != ""
}

# DO's ssh_key data source supports lookup by *name* (not fingerprint).
data "digitalocean_ssh_key" "selected_by_name" {
  count = local.use_name ? 1 : 0
  name  = local.ssh_key_name
}

# Build list for droplet.ssh_keys:
# - if fingerprint given -> pass it directly
# - else if name given   -> pass looked-up ID

locals {
  droplet_ssh_keys = local.use_fingerprint ? [local.ssh_key_fingerprint] : local.use_name ? [data.digitalocean_ssh_key.selected_by_name[0].id] : []
}


########################################
# Droplet
########################################

resource "digitalocean_droplet" "bbm" {
  image    = "ubuntu-22-04-x64"
  name     = "bbm-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = local.droplet_ssh_keys

  lifecycle {
    precondition {
      condition     = length(local.droplet_ssh_keys) > 0
      error_message = "Set either ssh_fingerprint or ssh_key_name to reference an existing SSH key uploaded to DigitalOcean."
    }
  }

  ########################################
  # Wait for cloud-init to finish
  ########################################
  provisioner "remote-exec" {
    inline = [
      "until cloud-init status --wait; do sleep 1; done",
      "echo 'Cloud-init completed'"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = self.ipv4_address
      timeout     = "5m"
    }
  }

  ########################################
  # Install Ruby & deps
  ########################################

  provisioner "remote-exec" {
    inline = [<<-BASH
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    # Never prompt on dpkg config file changes
    mkdir -p /etc/apt/apt.conf.d
    cat >/etc/apt/apt.conf.d/99no-prompt <<'APT'
    Dpkg::Options {
      "--force-confdef";
      "--force-confold";
    }
    APT

    # Auto-accept restarts (and also remove needrestart if present)
    mkdir -p /etc/needrestart/conf.d
    printf "$nrconf{restart} = 'a';\n$nrconf{kernelhints} = 0;\n" >/etc/needrestart/conf.d/90auto.conf || true
    if dpkg -s needrestart >/dev/null 2>&1; then
    apt-get -yq purge needrestart || true
    fi

    # Preseed tzdata to avoid dialog
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
    echo "tzdata tzdata/Areas select Etc" | debconf-set-selections
    echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections

    apt-get update -yq || apt-get update -y
    apt-get install -yq --no-install-recommends tzdata
    dpkg-reconfigure -f noninteractive tzdata

    # Install deps without prompts
    apt-get install -yq --no-install-recommends ruby ruby-dev build-essential git
    gem install bundler --no-document
    BASH
  ]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
    host        = self.ipv4_address
    timeout     = "15m"
  }
}


  ########################################
  # Copy application
  ########################################
  provisioner "file" {
    source      = "${path.module}/../"
    destination = "/root/bbm"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = self.ipv4_address
    }
  }

  ########################################
  # Configure env & run app
  ########################################
  provisioner "remote-exec" {
    inline = [
      "cd /root/bbm",
      "echo 'NBA_API_KEY=${var.nba_api_key}' > .env",
      "echo 'TELEGRAM_BOT_TOKEN=${var.telegram_bot_token}' >> .env",
      "echo 'TELEGRAM_CHAT_ID=${var.telegram_chat_id}' >> .env",
      "bundle install",
      "ruby app.rb"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = self.ipv4_address
      timeout     = "15m"
    }
  }

  ########################################
  # Local cleanup notice on destroy
  ########################################
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Droplet destroyed successfully'"
  }
}

########################################
# Outputs
########################################

output "droplet_ip" {
  value       = digitalocean_droplet.bbm.ipv4_address
  description = "The public IP address of the droplet"
}

output "droplet_name" {
  value       = digitalocean_droplet.bbm.name
  description = "The name of the droplet"
}

