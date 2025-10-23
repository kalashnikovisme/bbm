#!/bin/bash

# Script to run daily via cron for automated deployment and execution
# Add to crontab: 0 3 * * * /path/to/schedule.sh >> /var/log/bbm.log 2>&1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== BBM Daily Run Started at $(date) ==="

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Apply Terraform configuration (create droplet, run app)
echo "Creating droplet and running application..."
terraform apply -auto-approve

# Destroy the droplet after successful execution
echo "Destroying droplet..."
terraform destroy -auto-approve

echo "=== BBM Daily Run Completed at $(date) ==="
