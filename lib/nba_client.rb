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

    rows = linescore.css('tbody tr').select { |row| row.at_css('th') }
    return nil if rows.length < 2

    visitor_row = find_row(rows, 'visitor') || rows[0]
    home_row = find_row(rows, 'home') || rows[1]

    if visitor_row.equal?(home_row)
      home_row = rows.reject { |row| row.equal?(visitor_row) }.first
    end

    return nil unless visitor_row && home_row

    visitor_team = build_team(visitor_row)
    home_team = build_team(home_row)
    return nil unless visitor_team && home_team

    {
      'date' => date.strftime('%Y-%m-%d'),
      'status' => extract_status(summary),
      'home_team' => { 'full_name' => home_team[:name] },
      'visitor_team' => { 'full_name' => visitor_team[:name] },
      'home_team_score' => home_team[:points],
      'visitor_team_score' => visitor_team[:points]
    }
  end

  def build_team(row)
    name = extract_team_name(row)
    points = extract_points(row)

    return nil unless name && points

    { name: name, points: points }
  end

  def find_row(rows, keyword)
    rows.find do |row|
      class_list = row['class'].to_s.split
      class_match = class_list.any? { |cls| cls.downcase.include?(keyword) }

      header = row.at_css('th')
      header_attrs = if header
                       [header['data-stat'], header['class'], header['aria-label']].compact
                     else
                       []
                     end
      attr_match = header_attrs.map(&:downcase).any? { |attr| attr.include?(keyword) }

      class_match || attr_match
    end
  end

  def extract_team_name(row)
    header = row.at_css('th')
    return nil unless header

    name = header.at_css('a')&.text
    name = header.text if name.nil? || name.empty?
    name&.strip&.gsub(/\s+/, ' ')
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
