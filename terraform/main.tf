terraform {
  required_version = ">= 1.2"
  
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

locals {
  ssh_key_name        = trimspace(var.ssh_key_name)
  ssh_key_fingerprint = trimspace(var.ssh_fingerprint)
  use_fingerprint     = local.ssh_key_fingerprint != ""
  use_name            = !local.use_fingerprint && local.ssh_key_name != ""
}

data "digitalocean_ssh_key" "selected_by_fingerprint" {
  count       = local.use_fingerprint ? 1 : 0
  fingerprint = local.ssh_key_fingerprint
}

data "digitalocean_ssh_key" "selected_by_name" {
  count = local.use_name ? 1 : 0
  name  = local.ssh_key_name
}

locals {
  droplet_ssh_keys = compact(concat(
    data.digitalocean_ssh_key.selected_by_fingerprint[*].fingerprint,
    data.digitalocean_ssh_key.selected_by_name[*].fingerprint,
  ))
}

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

  # Wait for droplet to be ready
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

  # Install Ruby and dependencies
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y ruby ruby-dev build-essential git",
      "gem install bundler"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = self.ipv4_address
      timeout     = "10m"
    }
  }

  # Copy application files
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

  # Setup environment and run application
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

  # Cleanup - destroy droplet after execution
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Droplet destroyed successfully'"
  }
}

output "droplet_ip" {
  value       = digitalocean_droplet.bbm.ipv4_address
  description = "The public IP address of the droplet"
}

output "droplet_name" {
  value       = digitalocean_droplet.bbm.name
  description = "The name of the droplet"
}
