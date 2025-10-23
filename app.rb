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

  def run(target_date = Date.today - 1)
    scoreboard_url = scoreboard_url_for(target_date)

    puts "Fetching NBA games for #{target_date}..."
    puts "Scoreboard URL: #{scoreboard_url}"

    games = @nba_client.games_for(target_date)

    if games.empty?
      puts "No games found for #{target_date}."
      puts "Checked scoreboard: #{scoreboard_url}"
      @telegram_client.send_message("No NBA games were played #{formatted_date_phrase(target_date)}.")
      return
    end

    puts "Found #{games.length} game(s). Sending to Telegram..."

    games.each_with_index do |game, index|
      visitor_team = game.dig('visitor_team', 'full_name')
      home_team = game.dig('home_team', 'full_name')
      visitor_score = game['visitor_team_score']
      home_score = game['home_team_score']
      status = game['status']

      puts "Sending game #{index + 1}/#{games.length}: #{visitor_team} #{visitor_score} @ #{home_team} #{home_score} (#{status})"
      @telegram_client.send_game_score(game)
      puts "Game #{index + 1} dispatched to Telegram"
      sleep(1) # Rate limiting - wait 1 second between messages
    end

    puts 'All games sent successfully!'
  end

  private

  def scoreboard_url_for(date)
    "https://www.basketball-reference.com/boxscores/?month=#{date.month}&day=#{date.day}&year=#{date.year}"
  end

  def formatted_date_phrase(date)
    default_date = Date.today - 1
    return 'yesterday' if date == default_date

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
