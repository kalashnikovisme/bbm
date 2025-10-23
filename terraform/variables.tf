variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "droplet_size" {
  description = "Droplet size"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_fingerprint" {
  description = "Fingerprint of the SSH key uploaded to DigitalOcean"
  type        = string
  default     = ""
}

variable "ssh_key_name" {
  description = "Name of the SSH key uploaded to DigitalOcean (alternative to ssh_fingerprint)"
  type        = string
  default     = ""

  validation {
    condition     = length(trimspace(var.ssh_key_name)) > 0 || length(trimspace(var.ssh_fingerprint)) > 0
    error_message = "Provide either ssh_key_name or ssh_fingerprint to reference an existing SSH key in DigitalOcean."
  }
}

variable "nba_api_key" {
  description = "NBA API key (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token"
  type        = string
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "Telegram chat ID"
  type        = string
  sensitive   = true
}
