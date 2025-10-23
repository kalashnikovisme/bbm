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
    games_for(Date.today - 1)
  end

  def games_for(date)
    query = query_for(date)

    log("Fetching scoreboard for #{date} with query #{query}")

    response = self.class.get('/boxscores/', query: query, headers: request_headers)

    response_message = response.respond_to?(:message) ? response.message : nil
    log("Received HTTP #{response.code}#{" #{response_message}" if response_message}")

    raise "Failed to fetch games: #{response.code} - #{response_message || 'Unknown error'}" unless response.success?

    games = parse_games(response.body, date)
    log("Finished parsing scoreboard: #{games.length} game(s) extracted")

    games
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

    summaries = extract_game_summaries(document)
    log("Found #{summaries.length} potential game summary section(s)")

    games = []

    summaries.each_with_index do |summary, index|
      log("Parsing game summary ##{index + 1}")
      game = parse_game_summary(summary, date)

      if game
        log("Parsed game summary ##{index + 1}: #{format_game_log(game)}")
        games << game
      else
        log("Skipping game summary ##{index + 1}: insufficient data")
      end
    end

    games
  end

  def extract_game_summaries(document)
    summaries = document.css('div.game_summary').to_a
    unless summaries.empty?
      log("Discovered #{summaries.length} game summary div(s) in main document")
      return summaries
    end

    log('No game summaries found in main document; inspecting HTML comments')

    comment_summaries = document.xpath('//comment()').flat_map do |comment|
      next [] unless comment.text.include?('game_summary')

      fragment = Nokogiri::HTML(comment.text)
      fragment.css('div.game_summary')
    rescue Nokogiri::XML::SyntaxError
      []
    end

    log("Discovered #{comment_summaries.length} game summary div(s) inside HTML comments") unless comment_summaries.empty?

    comment_summaries
  end

  def parse_game_summary(summary, date)
    table, rows = locate_team_rows(summary)
    unless table && rows.length >= 2
      log('Skipping summary: unable to locate at least two team rows')
      return nil
    end

    visitor_row = find_row(rows, 'visitor') || rows[0]
    home_row = find_row(rows, 'home') || rows[1]

    if visitor_row.equal?(home_row)
      home_row = rows.reject { |row| row.equal?(visitor_row) }.first
    end

    unless visitor_row && home_row
      log('Skipping summary: visitor or home row could not be determined')
      return nil
    end

    visitor_team = build_team(visitor_row)
    home_team = build_team(home_row)
    unless visitor_team && home_team
      log('Skipping summary: unable to extract team names or scores')
      return nil
    end

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

  def locate_team_rows(summary)
    table = summary.at_css('table.linescore')
    rows = extract_team_rows(table)
    return [table, rows] if rows.length >= 2

    table = summary.at_css('table.teams')
    rows = extract_team_rows(table)
    return [table, rows] if rows.length >= 2

    summary.css('table').each do |candidate|
      rows = extract_team_rows(candidate)
      return [candidate, rows] if rows.length >= 2
    end

    [nil, []]
  end

  def extract_team_rows(table)
    return [] unless table

    rows = table.css('tbody tr')
    rows = table.css('tr') if rows.empty?

    rows.reject do |row|
      cells = row.css('th, td')
      cells.empty? || cells.all? { |cell| cell.text.strip.empty? }
    end
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
    cell = row.at_css('th, td')
    return nil unless cell

    name = cell.at_css('a')&.text
    name = cell.text if name.nil? || name.empty?
    name&.strip&.gsub(/\s+/, ' ')
  end

  def extract_points(row)
    points_cell = row.at_css('td[data-stat$="_pts"], td[data-stat$="_score"], td[data-stat="pts"], td[data-stat="team_pts"]')
    numeric_text = points_cell&.text&.strip

    numeric_text = nil unless numeric_text && numeric_text =~ /\A\d+\z/

    unless numeric_text
      numeric_text = row.css('td').map { |cell| cell.text.strip }.reverse.find { |text| text =~ /\A\d+\z/ }
    end

    return nil unless numeric_text && !numeric_text.empty?

    Integer(numeric_text)
  rescue ArgumentError
    nil
  end

  def extract_status(summary)
    status_node = summary.at_css('.game_status, .game_summary .status, .game_summary_status strong')
    status = status_node&.text&.strip
    status.nil? || status.empty? ? 'Final' : status
  end

  def format_game_log(game)
    visitor_team = game.dig('visitor_team', 'full_name')
    visitor_score = game['visitor_team_score']
    home_team = game.dig('home_team', 'full_name')
    home_score = game['home_team_score']
    status = game['status']

    "#{visitor_team} #{visitor_score} @ #{home_team} #{home_score} (#{status})"
  end

  def log(message)
    puts "[NbaClient] #{message}"
  end
end
