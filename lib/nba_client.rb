require 'httparty'
require 'nokogiri'
require 'date'

class NbaClient
  include HTTParty

  base_uri 'https://www.basketball-reference.com'

  USER_AGENT = 'Mozilla/5.0 (compatible; BBM Bot/1.0; +https://www.basketball-reference.com)'.freeze

  def initialize(user_agent = USER_AGENT)
    @user_agent = user_agent
  end

  def yesterday_games
    date = Date.today - 1
    response = self.class.get('/boxscores/', query: query_for(date), headers: request_headers)

    raise "Failed to fetch games: #{response.code} - #{response.message}" unless response.success?

    parse_games(response.body, date)
  end

  private

  def query_for(date)
    {
      month: date.month,
      day: date.day,
      year: date.year
    }
  end

  def request_headers
    { 'User-Agent' => @user_agent }
  end

  def parse_games(html, date)
    document = Nokogiri::HTML(html)

    document.css('div.game_summary').filter_map do |summary|
      parse_game_summary(summary, date)
    end
  end

  def parse_game_summary(summary, date)
    linescore = summary.at_css('table.linescore')
    return nil unless linescore

    rows = linescore.css('tbody tr')
    visitor_row = find_row(rows, 'visitor')
    home_row = find_row(rows, 'home')

    return nil unless visitor_row && home_row

    visitor_team_name = extract_team_name(visitor_row)
    home_team_name = extract_team_name(home_row)
    visitor_score = extract_points(visitor_row)
    home_score = extract_points(home_row)

    return nil unless visitor_team_name && home_team_name && visitor_score && home_score

    {
      'date' => date.strftime('%Y-%m-%d'),
      'status' => extract_status(summary),
      'home_team' => { 'full_name' => home_team_name },
      'visitor_team' => { 'full_name' => visitor_team_name },
      'home_team_score' => home_score,
      'visitor_team_score' => visitor_score
    }
  end

  def find_row(rows, keyword)
    rows.find do |row|
      header = row.at_css('th')
      header && header['data-stat']&.include?(keyword)
    end
  end

  def extract_team_name(row)
    row.at_css('th a')&.text&.strip
  end

  def extract_points(row)
    points_cell = row.at_css('td[data-stat$="_pts"]') || row.css('td').last
    return nil unless points_cell

    Integer(points_cell.text.strip)
  rescue ArgumentError
    nil
  end

  def extract_status(summary)
    status_node = summary.at_css('.game_status, .game_summary .status, .game_summary_status strong')
    status = status_node&.text&.strip
    status.nil? || status.empty? ? 'Final' : status
  end
end
