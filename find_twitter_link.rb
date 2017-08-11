require 'net/http'
require 'json'

# This is a simple Twitter Client which use application-only authentication
# for purpose of this demo, since this authenticationr equire no user interaction
class TwitterClient
  attr_reader :consumer_key, :consumer_secret, :access_token
  BASE_URL = 'https://api.twitter.com'

  def initialize(consumer_key, consumer_secret)
    @consumer_key, @consumer_secret = consumer_key, consumer_secret
  end

  # This is a public api for end-user to consume
  # @param string query
  def search(q)
    uri = URI(url('search/tweets.json'))
    uri.query = q
    execute_request uri, auth(Net::HTTP::Get.new(uri))
  end

  private
  def execute_request(uri, req)
    begin
      response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) {|http| http.request(req) }

      case response
      when Net::HTTPSuccess then
        JSON.parse(response.body)
      else
        nil
      end
    rescue
      # We may want to handle exception more gracefully 
      # And log into an exception tracking
    end
  end

  def auth(req)
    find_access_token unless access_token

    req.tap { |r| r['Authorization'] = "Bearer #{access_token}" }
  end

  def find_access_token
    uri = URI("#{BASE_URL}/oauth2/token")
    req = Net::HTTP::Post.new(uri)
    req.basic_auth consumer_key, consumer_secret
    req.set_form_data('grant_type' => 'client_credentials')
    req.content_type = 'application/x-www-form-urlencoded;charset=UTF-8'

    response = execute_request uri, req
    if response && response['access_token']
      @access_token = response['access_token']
    else
      raise "Fail to obtain access token"
    end
  end

  def url(path, version = '1.1')
    "#{BASE_URL}/#{version}/#{path}"
  end
end

# Searcher class
# We can expand to do any kind of search
class TweetSearch
  def initialize(client)
    @__client = client
  end

  def find_link_for_hash_tag(tag, count = 100)
    response = client.search(URI.encode_www_form(q: "\##{tag}", count: count))
    return unless response && response['statuses'].length > 0

    response['statuses'].map { |v| v['entities']['urls'] }
      .select { |uris| uris.length > 0 }
      .flatten
      .map { |v| v['expanded_url'] }
      .uniq
  end

  def output

  end

  private
  def client
    @__client
  end
end

# Format result from search
class Reporter
  def self.simple_output(uris)
    if uris.nil? || uris.length == 0
      puts 'Found no link'
      return
    end

    uris.each_with_index do |uri, index|
      puts "#{index + 1}. #{uri}"
    end
  end
end


CONSUMER_KEY    = ENV['CONSUMER_KEY']
CONSUMER_SECRET = ENV['CONSUMER_SECRET']
client          = TwitterClient.new(CONSUMER_KEY, CONSUMER_SECRET)
searcher        = TweetSearch.new client

Reporter.simple_output searcher.find_link_for_hash_tag(ARGV.first)
