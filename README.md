# BBM - Basketball Bot Messenger

A Ruby application that fetches NBA game scores from yesterday and sends them via Telegram bot. The application includes Terraform automation to deploy on DigitalOcean, run the bot, and clean up automatically.

## Features

- 🏀 Fetches all NBA games from yesterday using the [Balldontlie API](https://www.balldontlie.io/)
- 📱 Sends each game score as a separate Telegram message
- ☁️ Automated deployment using Terraform on DigitalOcean
- 🔄 Daily scheduled execution at 3 AM EST
- 🧹 Automatic cleanup (creates droplet, runs bot, destroys droplet)

## Prerequisites

- Ruby >= 2.7.0 (3.2.0 recommended)
- Bundler
- Telegram Bot Token (from [@BotFather](https://t.me/botfather))
- Your Telegram Chat ID
- DigitalOcean Account (for automated deployment)
- Terraform >= 1.2 (for automated deployment)

## Local Setup

1. Clone the repository:
```bash
git clone https://github.com/kalashnikovisme/bbm.git
cd bbm
```

2. Install dependencies:
```bash
bundle install
```

3. Create `.env` file from the example:
```bash
cp .env.example .env
```

4. Edit `.env` and add your credentials:
```env
NBA_API_KEY=                    # Optional - API works without it
TELEGRAM_BOT_TOKEN=your_token   # Get from @BotFather
TELEGRAM_CHAT_ID=your_chat_id   # Your Telegram chat/user ID
```

### Getting Your Telegram Chat ID

1. Start a chat with [@userinfobot](https://t.me/userinfobot)
2. The bot will reply with your chat ID

### Creating a Telegram Bot

1. Chat with [@BotFather](https://t.me/botfather)
2. Send `/newbot` command
3. Follow instructions to create your bot
4. Copy the API token provided

## Running Locally

### Using Ruby directly

```bash
ruby app.rb
```

### Using Make

```bash
make run
```

### Using Docker

```bash
docker-compose up
```

The application will:
1. Fetch all NBA games from yesterday
2. Send each game score as a Telegram message
3. Display progress in the console

## Terraform Deployment

### Setup

1. Navigate to the terraform directory:
```bash
cd terraform
```

2. Create `terraform.tfvars` from the example:
```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` with your credentials:
```hcl
do_token              = "your_digitalocean_api_token"
nba_api_key          = ""  # Optional
telegram_bot_token   = "your_telegram_bot_token"
telegram_chat_id     = "your_telegram_chat_id"
region               = "nyc1"
droplet_size         = "s-1vcpu-1gb"
ssh_private_key_path = "~/.ssh/id_rsa"
ssh_key_name         = ""                                   # Optional when ssh_fingerprint is set
ssh_fingerprint      = "3a:52:1f:ab:cd:ef:12:34:56:78:90:12:34:56:78:90"  # Provide either this or ssh_key_name
```

Set either `ssh_key_name` or `ssh_fingerprint` to reference an SSH key that already exists in your DigitalOcean account (Settings → Security). Terraform verifies that the key exists before creating the droplet and requires one of these values to be provided. If both are set, the fingerprint takes precedence.

When using fingerprints, the value should match the fingerprint displayed in the DigitalOcean control panel or returned by `ssh-keygen -lf ~/.ssh/id_rsa.pub` on your local machine.

4. Initialize Terraform:
```bash
terraform init
```

### Manual Deployment

To manually create a droplet, run the bot, and destroy the droplet:

```bash
terraform apply -auto-approve
terraform destroy -auto-approve
```

### Automated Daily Execution

To run the bot automatically every day at 3 AM EST:

1. Make the schedule script executable (already done):
```bash
chmod +x schedule.sh
```

2. Add to your crontab:
```bash
# Edit crontab
crontab -e

# Add this line (adjust path to your installation):
0 8 * * * /path/to/bbm/terraform/schedule.sh >> /var/log/bbm.log 2>&1
```

Note: The cron time `0 8 * * *` is 8 AM UTC, which equals 3 AM EST (UTC-5).

### GitHub Actions Manual Deployment

You can also deploy the bot manually using GitHub Actions:

1. Go to your repository on GitHub
2. Navigate to **Actions** → **Deploy Bot**
3. Click **Run workflow**
4. Choose an action:
   - `apply-and-destroy`: Creates droplet, runs bot, destroys droplet (default)
   - `apply-only`: Only creates droplet and runs bot
   - `destroy-only`: Only destroys existing infrastructure
5. Click **Run workflow** to start

#### Required GitHub Secrets

Set these in your repository settings (Settings → Secrets → Actions):

- `DO_TOKEN`: Your DigitalOcean API token
- `TELEGRAM_BOT_TOKEN`: Your Telegram bot token
- `TELEGRAM_CHAT_ID`: Your Telegram chat ID
- `NBA_API_KEY`: Optional NBA API key
- `SSH_PRIVATE_KEY`: Your SSH private key content
- `SSH_FINGERPRINT`: Fingerprint of the SSH key uploaded to DigitalOcean (optional if `SSH_KEY_NAME` is set)
- `SSH_KEY_NAME`: Name of the SSH key uploaded to DigitalOcean (optional if `SSH_FINGERPRINT` is set)

## Project Structure

```
bbm/
├── app.rb                    # Main application entry point
├── lib/
│   ├── nba_client.rb        # NBA API client
│   └── telegram_client.rb   # Telegram bot client
├── terraform/
│   ├── main.tf              # Terraform main configuration
│   ├── variables.tf         # Terraform variables
│   ├── terraform.tfvars.example
│   └── schedule.sh          # Daily execution script
├── Gemfile                   # Ruby dependencies
├── .env.example             # Environment variables template
└── README.md                # This file
```

## How It Works

### Application Flow

1. **NBA Client** (`lib/nba_client.rb`):
   - Connects to Balldontlie API
   - Fetches all games from yesterday
   - Returns game data including scores and team information

2. **Telegram Client** (`lib/telegram_client.rb`):
   - Formats game data into readable messages
   - Sends each game as a separate message
   - Includes team names, scores, date, and status

3. **Main App** (`app.rb`):
   - Orchestrates the flow
   - Fetches games from NBA API
   - Sends each game to Telegram
   - Handles errors and edge cases

### Terraform Automation

The Terraform configuration (`terraform/main.tf`):

1. **Creates** a minimal DigitalOcean droplet (1GB RAM, 1 CPU)
2. **Provisions** the droplet with:
   - Ubuntu 22.04 LTS
   - Ruby and dependencies
   - Application code
3. **Executes** the bot to fetch and send game scores
4. **Destroys** the droplet automatically after completion

This approach minimizes costs by only running infrastructure when needed.

## Cost Estimation

Running daily on DigitalOcean:
- Droplet: $0.007/hour × ~0.1 hours/day = ~$0.0007/day
- Monthly: ~$0.02/month

Essentially free! 💰

## Configuration Options

### Terraform Variables

- `do_token`: DigitalOcean API token (required)
- `region`: DigitalOcean region (default: `nyc1`)
- `droplet_size`: Droplet size (default: `s-1vcpu-1gb`)
- `nba_api_key`: NBA API key (optional)
- `telegram_bot_token`: Telegram bot token (required)
- `telegram_chat_id`: Telegram chat ID (required)

### Environment Variables

- `NBA_API_KEY`: Optional API key for Balldontlie
- `TELEGRAM_BOT_TOKEN`: Your Telegram bot token
- `TELEGRAM_CHAT_ID`: Your Telegram chat or channel ID

## Available Commands

This project includes a Makefile for convenience:

```bash
make help          # Show all available commands
make install       # Install dependencies
make test          # Run tests
make lint          # Run linter
make lint-fix      # Auto-fix linting issues
make run           # Run the application
make setup         # Initial setup
make terraform-*   # Terraform-related commands
```

## Troubleshooting

### No games found
- The NBA season typically runs from October to June
- Check if there were actually games yesterday

### Telegram not receiving messages
- Verify your bot token is correct
- Ensure you've started a conversation with your bot
- Check your chat ID is correct

### Terraform errors
- Ensure your DigitalOcean token is valid
- Check you have sufficient permissions
- Verify SSH keys exist at specified paths

## Development

### Running Tests

```bash
bundle exec rspec
```

### Linting

```bash
bundle exec rubocop
```

## License

MIT

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request