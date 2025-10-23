require_relative '../lib/nba_client'
require_relative 'spec_helper'

RSpec.describe NbaClient do
  let(:client) { described_class.new }
  let(:yesterday) { Date.today - 1 }

  describe '#yesterday_games' do
    context 'when API returns games successfully' do
      let(:mock_response) do
        {
          'data' => [
            {
              'id' => 1,
              'date' => yesterday.to_s,
              'home_team' => { 'full_name' => 'Los Angeles Lakers' },
              'visitor_team' => { 'full_name' => 'Boston Celtics' },
              'home_team_score' => 105,
              'visitor_team_score' => 98,
              'status' => 'Final'
            }
          ]
        }
      end

      before do
        stub_request(:get, 'https://www.balldontlie.io/api/v1/games')
          .with(query: { dates: [yesterday.to_s], per_page: 100 })
          .to_return(status: 200, body: mock_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns games data' do
        games = client.yesterday_games
        expect(games).to be_an(Array)
        expect(games.length).to eq(1)
        expect(games.first['home_team']['full_name']).to eq('Los Angeles Lakers')
      end
    end

    context 'when API returns empty games' do
      before do
        stub_request(:get, 'https://www.balldontlie.io/api/v1/games')
          .with(query: { dates: [yesterday.to_s], per_page: 100 })
          .to_return(status: 200, body: { 'data' => [] }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns empty array' do
        games = client.yesterday_games
        expect(games).to be_an(Array)
        expect(games).to be_empty
      end
    end

    context 'when API request fails' do
      before do
        stub_request(:get, 'https://www.balldontlie.io/api/v1/games')
          .with(query: { dates: [yesterday.to_s], per_page: 100 })
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error' do
        expect { client.yesterday_games }.to raise_error(/Failed to fetch games/)
      end
    end
  end
end
