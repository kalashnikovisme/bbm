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
                <table class="teams">
                  <tbody>
                    <tr class="team visitor winner">
                      <th scope="row" data-stat="team_name"><a href="/teams/LAL/2024.html">Los Angeles Lakers</a></th>
                      <td class="center" data-stat="q1">34</td>
                      <td class="center" data-stat="q2">28</td>
                      <td class="center" data-stat="q3">27</td>
                      <td class="center" data-stat="q4">23</td>
                      <td class="center strong" data-stat="team_pts">112</td>
                    </tr>
                    <tr class="team home">
                      <th scope="row" data-stat="team_name"><a href="/teams/BOS/2024.html">Boston Celtics</a></th>
                      <td class="center" data-stat="q1">27</td>
                      <td class="center" data-stat="q2">24</td>
                      <td class="center" data-stat="q3">26</td>
                      <td class="center" data-stat="q4">31</td>
                      <td class="center strong" data-stat="team_pts">108</td>
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

    context 'when scoreboard is wrapped in HTML comments' do
      let(:scoreboard_html) do
        <<~HTML
          <html>
            <body>
              <!--
              <div class="game_summary">
                <table class="teams">
                  <tbody>
                    <tr>
                      <th scope="row"><a href="/teams/CHI/2024.html">Chicago Bulls</a></th>
                      <td>30</td>
                      <td>24</td>
                      <td>29</td>
                      <td>23</td>
                      <td>106</td>
                    </tr>
                    <tr>
                      <th scope="row"><a href="/teams/MIL/2024.html">Milwaukee Bucks</a></th>
                      <td>28</td>
                      <td>27</td>
                      <td>22</td>
                      <td>30</td>
                      <td>107</td>
                    </tr>
                  </tbody>
                </table>
                <div class="game_status">Final</div>
              </div>
              -->
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

      it 'parses games that are hidden behind HTML comments' do
        games = client.yesterday_games

        expect(games.length).to eq(1)
        first_game = games.first
        expect(first_game['visitor_team']['full_name']).to eq('Chicago Bulls')
        expect(first_game['home_team']['full_name']).to eq('Milwaukee Bucks')
        expect(first_game['visitor_team_score']).to eq(106)
        expect(first_game['home_team_score']).to eq(107)
      end
    end

    context 'when scoreboard rows lack explicit visitor/home markers' do
      let(:scoreboard_html) do
        <<~HTML
          <html>
            <body>
              <div class="game_summary">
                <table>
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

    context 'when scoreboard uses legacy linescore tables' do
      let(:scoreboard_html) do
        <<~HTML
          <html>
            <body>
              <div class="game_summary">
                <table class="linescore">
                  <tbody>
                    <tr class="team visitor">
                      <th scope="row"><a href="/teams/DAL/2024.html">Dallas Mavericks</a></th>
                      <td class="center">25</td>
                      <td class="center strong">101</td>
                    </tr>
                    <tr class="team home">
                      <th scope="row"><a href="/teams/PHX/2024.html">Phoenix Suns</a></th>
                      <td class="center">30</td>
                      <td class="center strong">110</td>
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

      it 'still parses games from the legacy layout' do
        games = client.yesterday_games

        expect(games.length).to eq(1)
        game = games.first
        expect(game['visitor_team']['full_name']).to eq('Dallas Mavericks')
        expect(game['home_team']['full_name']).to eq('Phoenix Suns')
        expect(game['visitor_team_score']).to eq(101)
        expect(game['home_team_score']).to eq(110)
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
