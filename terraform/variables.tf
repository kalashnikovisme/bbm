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
