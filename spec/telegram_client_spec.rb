require_relative '../lib/telegram_client'
require_relative 'spec_helper'

RSpec.describe TelegramClient do
  let(:token) { 'fake_token' }
  let(:chat_id) { '12345' }
  let(:client) { described_class.new(token, chat_id) }

  describe '#format_game_message' do
    let(:game) do
      {
        'home_team' => { 'full_name' => 'Los Angeles Lakers' },
        'visitor_team' => { 'full_name' => 'Boston Celtics' },
        'home_team_score' => 105,
        'visitor_team_score' => 98,
        'date' => '2023-10-22',
        'status' => 'Final'
      }
    end

    it 'formats final game message correctly' do
      message = client.send(:format_game_message, game)

      expect(message).to include('NBA Game Result')
      expect(message).to include('Boston Celtics: 98')
      expect(message).to include('Los Angeles Lakers: 105')
      expect(message).to include('2023-10-22')
      expect(message).to include('Final')
    end

    context 'when game is not final' do
      before { game['status'] = 'In Progress' }

      it 'formats non-final game message correctly' do
        message = client.send(:format_game_message, game)

        expect(message).to include('NBA Game')
        expect(message).to include('Boston Celtics vs Los Angeles Lakers')
        expect(message).to include('Status: In Progress')
      end
    end
  end

  describe '#send_message' do
    let(:bot_double) { instance_double(Telegram::Bot::Client) }
    let(:api_double) { double('api') }

    before do
      allow(Telegram::Bot::Client).to receive(:run).with(token).and_yield(bot_double)
      allow(bot_double).to receive(:api).and_return(api_double)
    end

    it 'sends message via Telegram API' do
      expect(api_double).to receive(:send_message)
        .with(chat_id: chat_id, text: 'Test message')

      client.send_message('Test message')
    end
  end
end
