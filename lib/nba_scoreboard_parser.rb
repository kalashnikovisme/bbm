class NbaScoreboardParser
  def initialize(logger: nil, summary_collector: nil, game_builder: nil)
    @logger = logger
    @summary_collector = summary_collector
    @game_builder = game_builder
  end

  def parse(html, date)
    document = Nokogiri::HTML(html)
    summaries = summary_collector.collect(document)
    log("Found #{summaries.length} potential game summary section(s)")

    summaries.each_with_index.with_object([]) do |(summary, index), games|
      log("Parsing game summary ##{index + 1}")
      game = game_builder.build(summary, date)

      if game
        log("Parsed game summary ##{index + 1}: #{format_game_log(game)}")
        games << game
      else
        log("Skipping game summary ##{index + 1}: insufficient data")
      end
    end
  end

  private

  attr_reader :logger

  def summary_collector
    @summary_collector ||= NbaSummaryCollector.new(logger: logger)
  end

  def game_builder
    @game_builder ||= NbaGameBuilder.new(logger: logger)
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
    logger&.call(message)
  end
end

class NbaSummaryCollector
  def initialize(logger: nil)
    @logger = logger
  end

  def collect(document)
    summaries = document.css('div.game_summary').to_a
    return log_main_document(summaries) unless summaries.empty?

    log('No game summaries found in main document; inspecting HTML comments')
    comment_summaries = extract_comment_summaries(document)
    log_comment_document(comment_summaries)
    comment_summaries
  end

  private

  attr_reader :logger

  def log_main_document(summaries)
    log("Discovered #{summaries.length} game summary div(s) in main document")
    summaries
  end

  def extract_comment_summaries(document)
    document.xpath('//comment()').each_with_object([]) do |comment, collected|
      next unless comment.text.include?('game_summary')

      fragment = Nokogiri::HTML(comment.text)
      collected.concat(fragment.css('div.game_summary'))
    rescue Nokogiri::XML::SyntaxError
      next
    end
  end

  def log_comment_document(summaries)
    return if summaries.empty?

    log("Discovered #{summaries.length} game summary div(s) inside HTML comments")
  end

  def log(message)
    logger&.call(message)
  end
end

class NbaGameBuilder
  def initialize(logger: nil, row_locator: nil, team_extractor: nil)
    @logger = logger
    @row_locator = row_locator
    @team_extractor = team_extractor
  end

  def build(summary, date)
    rows = row_locator.rows_for(summary)
    return log_and_skip('Skipping summary: unable to locate at least two team rows') if rows.length < 2

    visitor_row, home_row = row_locator.assign_rows(rows)
    return log_and_skip('Skipping summary: visitor or home row could not be determined') unless visitor_row && home_row

    visitor_team = team_extractor.from_row(visitor_row)
    home_team = team_extractor.from_row(home_row)
    return log_and_skip('Skipping summary: unable to extract team names or scores') unless visitor_team && home_team

    assemble_game(date, summary, visitor_team, home_team)
  end

  private

  attr_reader :logger

  def row_locator
    @row_locator ||= NbaTeamRowLocator.new
  end

  def team_extractor
    @team_extractor ||= NbaTeamExtractor.new
  end

  def assemble_game(date, summary, visitor_team, home_team)
    {
      'date' => date.strftime('%Y-%m-%d'),
      'status' => status_from(summary),
      'home_team' => { 'full_name' => home_team[:name] },
      'visitor_team' => { 'full_name' => visitor_team[:name] },
      'home_team_score' => home_team[:points],
      'visitor_team_score' => visitor_team[:points]
    }
  end

  def status_from(summary)
    status_node = summary.at_css('.game_status, .game_summary .status, .game_summary_status strong')
    status = status_node&.text&.strip
    status.nil? || status.empty? ? 'Final' : status
  end

  def log_and_skip(message)
    log(message)
    nil
  end

  def log(message)
    logger&.call(message)
  end
end

class NbaTeamRowLocator
  def rows_for(summary)
    candidate_tables(summary).each do |table|
      rows = extract_rows(table)
      return rows if rows.length >= 2
    end

    []
  end

  def assign_rows(rows)
    visitor_row = find_row(rows, 'visitor') || rows[0]
    home_row = find_row(rows, 'home') || rows[1]

    [visitor_row, distinct_home_row(rows, visitor_row, home_row)]
  end

  private

  def candidate_tables(summary)
    preferred = [summary.at_css('table.linescore'), summary.at_css('table.teams')]
    (preferred + summary.css('table').to_a).compact.uniq
  end

  def extract_rows(table)
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
      class_match?(row, keyword) || header_match?(row, keyword)
    end
  end

  def class_match?(row, keyword)
    row['class'].to_s.split.any? { |cls| cls.downcase.include?(keyword) }
  end

  def header_match?(row, keyword)
    header = row.at_css('th')
    return false unless header

    header_attrs = [header['data-stat'], header['class'], header['aria-label']].compact
    header_attrs.map(&:downcase).any? { |attr| attr.include?(keyword) }
  end

  def distinct_home_row(rows, visitor_row, home_row)
    return home_row unless visitor_row.equal?(home_row)

    rows.find { |row| !row.equal?(visitor_row) }
  end
end

class NbaTeamExtractor
  POINTS_SELECTORS = [
    'td[data-stat$="_pts"]',
    'td[data-stat$="_score"]',
    'td[data-stat="pts"]',
    'td[data-stat="team_pts"]'
  ].freeze
  NUMERIC_TEXT = /\A\d+\z/.freeze

  def from_row(row)
    name = team_name(row)
    points = points(row)
    return nil unless name && points

    { name: name, points: points }
  end

  private

  def team_name(row)
    cell = row.at_css('th, td')
    return nil unless cell

    name = cell.at_css('a')&.text
    name = cell.text if name.nil? || name.empty?
    name&.strip&.gsub(/\s+/, ' ')
  end

  def points(row)
    numeric_text = numeric_text_from(points_cell(row))
    numeric_text ||= fallback_numeric_text(row)
    return nil unless numeric_text

    Integer(numeric_text)
  rescue ArgumentError
    nil
  end

  def points_cell(row)
    POINTS_SELECTORS.each do |selector|
      cell = row.at_css(selector)
      return cell if cell
    end

    nil
  end

  def numeric_text_from(cell)
    text = cell&.text&.strip
    return nil unless numeric?(text)

    text
  end

  def fallback_numeric_text(row)
    row.css('td').reverse_each do |cell|
      text = cell.text.strip
      return text if numeric?(text)
    end

    nil
  end

  def numeric?(text)
    text && NUMERIC_TEXT.match?(text)
  end
end
