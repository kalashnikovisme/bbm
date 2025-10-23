require 'httparty'
require 'date'

class NbaClient
  include HTTParty

  base_uri 'https://www.balldontlie.io/api/v1'

  def initialize(api_key = nil)
    @api_key = api_key
  end

  def yesterday_games
    yesterday = Date.today - 1
    response = self.class.get('/games', query: {
                                dates: [yesterday.to_s],
                                per_page: 100
                              }, headers: headers)

    raise "Failed to fetch games: #{response.code} - #{response.message}" unless response.success?

    response.parsed_response['data']
  end

  private

  def headers
    return {} unless @api_key

    { 'Authorization' => @api_key }
  end
end
