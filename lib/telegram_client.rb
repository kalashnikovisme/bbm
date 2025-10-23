require 'telegram/bot'

class TelegramClient
  def initialize(token, chat_id)
    @token = token
    @chat_id = chat_id
  end

  def send_message(text)
    Telegram::Bot::Client.run(@token) do |bot|
      bot.api.send_message(chat_id: @chat_id, text: text)
    end
  end

  def send_game_score(game)
    message = format_game_message(game)
    send_message(message)
  end

  private

  def format_game_message(game)
    home_team = game['home_team']['full_name']
    visitor_team = game['visitor_team']['full_name']
    home_score = game['home_team_score']
    visitor_score = game['visitor_team_score']
    game_date = game['date']
    status = game['status']

    if status == 'Final'
      "🏀 NBA Game Result\n\n" \
        "#{visitor_team}: #{visitor_score}\n" \
        "#{home_team}: #{home_score}\n\n" \
        "📅 #{game_date}\n" \
        '✅ Final'
    else
      "🏀 NBA Game\n\n" \
        "#{visitor_team} vs #{home_team}\n" \
        "📅 #{game_date}\n" \
        "Status: #{status}"
    end
  end
end
