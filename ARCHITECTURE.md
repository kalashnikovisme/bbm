# BBM Architecture

## Overview

BBM (Basketball Bot Messenger) is a Ruby application that fetches NBA game scores and distributes them via Telegram. The system is designed for automated, cost-effective operation using ephemeral infrastructure.

## System Components

### 1. Ruby Application

#### NBA Client (`lib/nba_client.rb`)
- Fetches game data from Balldontlie API
- Filters for yesterday's games
- Handles API errors gracefully
- Supports optional API key authentication

#### Telegram Client (`lib/telegram_client.rb`)
- Formats game data into readable messages
- Sends messages to configured Telegram chat
- Includes emojis for better UX
- Handles both final and in-progress games

#### Main Application (`app.rb`)
- Orchestrates the workflow
- Fetches games from NBA API
- Iterates through games and sends to Telegram
- Includes rate limiting (1 second between messages)
- Provides console feedback

### 2. Infrastructure as Code (Terraform)

#### Terraform Configuration (`terraform/`)
- Creates minimal DigitalOcean droplet (1GB RAM, 1 vCPU)
- Provisions droplet with Ruby environment
- Copies application code to droplet
- Runs the application
- Automatically destroys droplet after completion

#### Scheduling (`terraform/schedule.sh`)
- Bash script for automated execution
- Designed to run via cron at 3 AM EST daily
- Handles Terraform initialization
- Applies configuration (create + run)
- Destroys infrastructure after completion

## Data Flow

```
┌─────────────────────┐
│   Cron Schedule     │
│   (3 AM EST)        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Terraform Apply    │
│  (schedule.sh)      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Create Droplet     │
│  (DigitalOcean)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Provision Ruby     │
│  Environment        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Copy & Run App     │
│  (app.rb)           │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐     ┌─────────────────────┐
│  Fetch NBA Games    │────▶│  Balldontlie API    │
│  (NbaClient)        │     │  (Yesterday's games)│
└──────────┬──────────┘     └─────────────────────┘
           │
           ▼
┌─────────────────────┐     ┌─────────────────────┐
│  Send to Telegram   │────▶│  Telegram Bot API   │
│  (TelegramClient)   │     │  (Chat messages)    │
└──────────┬──────────┘     └─────────────────────┘
           │
           ▼
┌─────────────────────┐
│  Terraform Destroy  │
│  (schedule.sh)      │
└─────────────────────┘
```

## Design Decisions

### Ephemeral Infrastructure
- **Why**: Minimize costs by only running infrastructure when needed
- **How**: Terraform creates droplet, runs app, then destroys droplet
- **Cost**: ~$0.0007/day (~$0.02/month)

### Ruby + HTTParty + Telegram Bot
- **Why**: Simple, well-supported libraries for HTTP and Telegram
- **Alternatives considered**: Python, Node.js (chose Ruby for simplicity)

### DigitalOcean
- **Why**: Simple API, good Terraform support, cost-effective
- **Alternatives**: AWS Lambda, GCP Cloud Functions (chose DO for simplicity)

### Schedule at 3 AM EST
- **Why**: NBA games typically finish by midnight EST
- **How**: Cron job runs at 8 AM UTC (3 AM EST)

### Rate Limiting
- **Why**: Avoid hitting Telegram API limits
- **How**: 1 second delay between messages

## Security Considerations

1. **Environment Variables**: Sensitive data (tokens, keys) stored in `.env`
2. **Terraform Variables**: Sensitive terraform vars marked as `sensitive = true`
3. **SSH Keys**: Used for secure droplet provisioning
4. **API Keys**: Optional NBA API key, required Telegram token

## Testing Strategy

### Unit Tests (`spec/`)
- Test NBA client API interactions (mocked)
- Test Telegram client message formatting
- Test error handling
- Use WebMock to stub external APIs

### CI/CD (GitHub Actions)
- Run tests on multiple Ruby versions (2.7, 3.0, 3.1, 3.2)
- Run RuboCop linting
- Validate Terraform configuration

## Scalability

### Current Design
- Single droplet, sequential processing
- Suitable for ~30 games/day (typical NBA schedule)
- ~30 seconds total runtime

### Future Enhancements
- Parallel message sending
- Multiple Telegram channels/chats
- Support for other sports APIs
- Historical game data
- Game highlights integration

## Monitoring & Debugging

### Logs
- Console output during execution
- Schedule script logs to `/var/log/bbm.log`
- Terraform state for troubleshooting

### Error Handling
- API failures raise exceptions
- Empty game list sends notification
- Rate limiting prevents API bans

## Dependencies

### Ruby Gems
- `httparty`: HTTP requests to NBA API
- `telegram-bot-ruby`: Telegram Bot API integration
- `dotenv`: Environment variable management
- `rspec`: Testing framework
- `webmock`: HTTP mocking for tests
- `rubocop`: Code linting

### External Services
- Balldontlie API: NBA game data
- Telegram Bot API: Message delivery
- DigitalOcean: Infrastructure hosting

## Development Workflow

1. Local development with `.env` file
2. Test with RSpec: `bundle exec rspec`
3. Lint with RuboCop: `bundle exec rubocop`
4. Manual test: `ruby app.rb`
5. Terraform test: `cd terraform && terraform apply`
6. Deploy: Set up cron job with `schedule.sh`

## Cost Analysis

### Daily Operation
- Droplet: $0.007/hour × 0.01 hours = $0.00007
- API Calls: Free (Balldontlie, Telegram)
- **Total**: ~$0.0007/day

### Monthly Cost
- ~$0.02/month
- Essentially free! 💰

## Future Improvements

1. **Notification channels**: Discord, Slack, Email
2. **Game filters**: Specific teams, scores thresholds
3. **Live updates**: In-game score updates
4. **Analytics**: Track most active days, popular teams
5. **Web dashboard**: View sent messages, statistics
6. **Database**: Store historical game data
7. **Kubernetes**: For larger scale operations
