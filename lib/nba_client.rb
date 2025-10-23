require 'httparty'
require 'nokogiri'
require 'date'

require_relative 'nba_scoreboard_parser'

class NbaClient
  include HTTParty

  base_uri 'https://www.basketball-reference.com'

  USER_AGENT = 'Mozilla/5.0 (compatible; BBM Bot/1.0; +https://www.basketball-reference.com)'.freeze

  def initialize(user_agent = USER_AGENT, parser_class: NbaScoreboardParser)
    @user_agent = user_agent
    @parser_class = parser_class
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

    parser = @parser_class.new(logger: method(:log))
    games = parser.parse(response.body, date)
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

  def log(message)
    puts "[NbaClient] #{message}"
  end
end
