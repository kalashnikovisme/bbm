require_relative '../lib/nba_client'
require_relative 'spec_helper'

RSpec.describe NbaClient do
  let(:client) { described_class.new }
  let(:yesterday) { Date.today - 1 }

  describe '#yesterday_games' do
    context 'when scoreboard has completed games' do
      let(:scoreboard_html) do
        <<~HTML
          <html>
            <body>
              <div class="game_summary">
                <table class="linescore">
                  <tbody>
                    <tr class="team visitor winner">
                      <th scope="row"><a href="/teams/LAL/2024.html">Los Angeles Lakers</a></th>
                      <td class="center">34</td>
                      <td class="center strong">112</td>
                    </tr>
                    <tr class="team home">
                      <th scope="row"><a href="/teams/BOS/2024.html">Boston Celtics</a></th>
                      <td class="center">27</td>
                      <td class="center strong">108</td>
                    </tr>
                  </tbody>
                </table>
                <div class="game_summary_meta">
                  <p class="game_status">Final</p>
                </div>
              </div>
            </body>
          </html>
        HTML
      end

      before do
        stub_request(:get, 'https://www.basketball-reference.com/boxscores/')
          .with(
            query: hash_including(
              'month' => yesterday.month.to_s,
              'day' => yesterday.day.to_s,
              'year' => yesterday.year.to_s
            )
          )
          .to_return(
            status: 200,
            body: scoreboard_html,
            headers: { 'Content-Type' => 'text/html' }
          )
      end

      it 'returns parsed games data' do
        games = client.yesterday_games

        expect(games).to be_an(Array)
        expect(games.length).to eq(1)
        expect(games.first['home_team']['full_name']).to eq('Boston Celtics')
        expect(games.first['visitor_team']['full_name']).to eq('Los Angeles Lakers')
        expect(games.first['home_team_score']).to eq(108)
        expect(games.first['visitor_team_score']).to eq(112)
        expect(games.first['status']).to eq('Final')
        expect(games.first['date']).to eq(yesterday.strftime('%Y-%m-%d'))
      end
    end

    context 'when scoreboard rows lack explicit visitor/home markers' do
      let(:scoreboard_html) do
        <<~HTML
          <html>
            <body>
              <div class="game_summary">
                <table class="linescore">
                  <tbody>
                    <tr>
                      <th scope="row"><a href="/teams/MIA/2024.html">Miami Heat</a></th>
                      <td class="center">28</td>
                      <td class="center strong">102</td>
                    </tr>
                    <tr>
                      <th scope="row"><a href="/teams/NYK/2024.html">New York Knicks</a></th>
                      <td class="center">25</td>
                      <td class="center strong">99</td>
                    </tr>
                  </tbody>
                </table>
                <div class="game_status">Final</div>
              </div>
            </body>
          </html>
        HTML
      end

      before do
        stub_request(:get, 'https://www.basketball-reference.com/boxscores/')
          .with(
            query: hash_including(
              'month' => yesterday.month.to_s,
              'day' => yesterday.day.to_s,
              'year' => yesterday.year.to_s
            )
          )
          .to_return(
            status: 200,
            body: scoreboard_html,
            headers: { 'Content-Type' => 'text/html' }
          )
      end

      it 'infers the visitor and home teams by row order' do
        games = client.yesterday_games

        expect(games.length).to eq(1)
        first_game = games.first
        expect(first_game['visitor_team']['full_name']).to eq('Miami Heat')
        expect(first_game['home_team']['full_name']).to eq('New York Knicks')
        expect(first_game['visitor_team_score']).to eq(102)
        expect(first_game['home_team_score']).to eq(99)
      end
    end

    context 'when the scoreboard has no games' do
      before do
        stub_request(:get, 'https://www.basketball-reference.com/boxscores/')
          .with(
            query: hash_including(
              'month' => yesterday.month.to_s,
              'day' => yesterday.day.to_s,
              'year' => yesterday.year.to_s
            )
          )
          .to_return(
            status: 200,
            body: '<html><body>No games</body></html>',
            headers: { 'Content-Type' => 'text/html' }
          )
      end

      it 'returns empty array' do
        games = client.yesterday_games
        expect(games).to be_an(Array)
        expect(games).to be_empty
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:get, 'https://www.basketball-reference.com/boxscores/')
          .with(
            query: hash_including(
              'month' => yesterday.month.to_s,
              'day' => yesterday.day.to_s,
              'year' => yesterday.year.to_s
            )
          )
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error' do
        expect { client.yesterday_games }.to raise_error(/Failed to fetch games/)
      end
    end
  end
end
