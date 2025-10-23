#!/usr/bin/env ruby

require 'date'
require 'dotenv/load'
require_relative 'lib/nba_client'
require_relative 'lib/telegram_client'

class App
  def initialize
    @nba_client = NbaClient.new
    @telegram_client = TelegramClient.new(
      ENV.fetch('TELEGRAM_BOT_TOKEN', nil),
      ENV.fetch('TELEGRAM_CHAT_ID', nil)
    )
  end

  def run(target_date = default_target_date)
    scoreboard_url = scoreboard_url_for(target_date)

    log_fetch_start(target_date, scoreboard_url)

    games = @nba_client.games_for(target_date)

    return handle_no_games(target_date, scoreboard_url) if games.empty?

    dispatch_games(games)

    puts 'All games sent successfully!'
  end

  private

  def default_target_date
    Date.today - 1
  end

  def log_fetch_start(target_date, scoreboard_url)
    puts "Fetching NBA games for #{target_date}..."
    puts "Scoreboard URL: #{scoreboard_url}"
  end

  def handle_no_games(target_date, scoreboard_url)
    puts "No games found for #{target_date}."
    puts "Checked scoreboard: #{scoreboard_url}"
    @telegram_client.send_message("No NBA games were played #{formatted_date_phrase(target_date)}.")
  end

  def dispatch_games(games)
    puts "Found #{games.length} game(s). Sending to Telegram..."

    games.each_with_index do |game, index|
      log_game_delivery(game, index, games.length)
      @telegram_client.send_game_score(game)
      puts "Game #{index + 1} dispatched to Telegram"
      sleep(1) # Rate limiting - wait 1 second between messages
    end
  end

  def log_game_delivery(game, index, total)
    visitor_team = game.dig('visitor_team', 'full_name')
    home_team = game.dig('home_team', 'full_name')
    visitor_score = game['visitor_team_score']
    home_score = game['home_team_score']
    status = game['status']

    message = format(
      'Sending game %<current>d/%<total>d: %<visitor>s %<visitor_score>d @ %<home>s %<home_score>d (%<status>s)',
      current: index + 1,
      total: total,
      visitor: visitor_team,
      visitor_score: visitor_score,
      home: home_team,
      home_score: home_score,
      status: status
    )

    puts message
  end

  def scoreboard_url_for(date)
    "https://www.basketball-reference.com/boxscores/?month=#{date.month}&day=#{date.day}&year=#{date.year}"
  end

  def formatted_date_phrase(date)
    return 'yesterday' if date == default_target_date

    "on #{date.strftime('%B %-d, %Y')}"
  end
end

if __FILE__ == $PROGRAM_NAME
  date_argument = ARGV.first

  target_date = if date_argument.nil? || date_argument.empty?
                  Date.today - 1
                else
                  begin
                    Date.parse(date_argument)
                  rescue ArgumentError
                    warn "Invalid date format: #{date_argument}. Please use YYYY-MM-DD."
                    exit 1
                  end
                end

  App.new.run(target_date)
end
