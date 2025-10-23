#!/usr/bin/env ruby

require 'dotenv/load'
require_relative 'lib/nba_client'
require_relative 'lib/telegram_client'

class App
  def initialize
    @nba_client = NbaClient.new(ENV.fetch('NBA_API_KEY', nil))
    @telegram_client = TelegramClient.new(
      ENV.fetch('TELEGRAM_BOT_TOKEN', nil),
      ENV.fetch('TELEGRAM_CHAT_ID', nil)
    )
  end

  def run
    puts "Fetching yesterday's NBA games..."
    games = @nba_client.yesterday_games

    if games.empty?
      puts 'No games found for yesterday.'
      @telegram_client.send_message('No NBA games were played yesterday.')
      return
    end

    puts "Found #{games.length} game(s). Sending to Telegram..."

    games.each_with_index do |game, index|
      puts "Sending game #{index + 1}/#{games.length}..."
      @telegram_client.send_game_score(game)
      sleep(1) # Rate limiting - wait 1 second between messages
    end

    puts 'All games sent successfully!'
  end
end

App.new.run if __FILE__ == $PROGRAM_NAME
