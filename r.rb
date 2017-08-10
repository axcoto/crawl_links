#!/usr/bin/env ruby

require 'open-uri'
require 'thread'
require 'openssl'

class Crawler
  attr_reader :url, :term, :base_url

  def initialize(url, term)
    @url, @term = url, term
    r = URI.parse(url)
    @base_url = "#{r.scheme}://#{r.host}"
    @done = false

    # Using queue for thread safe
    @links = Queue.new

    @results = []
    @stats =  {crawler: 0}
    @workers = []
  end

  def worker
    while true
      begin
        link = links.pop
        puts link
        if link
          lookup_url = link[:url]

          response = open(lookup_url).read

          urls  = response.scan(/<a.+?href="(.+?)"/)
          if link[:level] < 2
            urls.select { |l| l.first.start_with?(base_url) }
              .map { |l| l = "#{base_url}#{l.first}" if l.first.start_with?("/") }
              .each { links.push({url: l.first, level: link[:level] + 1}) }
          end

          if (text_only = response.gsub(/<\/?[^>]*>/, "")) && text_only.include?(term)
            @results << lookup_url
          end
        end
      rescue => e
        puts e
      end

      puts "fetch"
      puts "hey"
    end
  end

  def spawn_worker
    10.times do |i|
      @workers << Thread.new do
        worker
      end
    end
  end

  def start
    links << {url: url, level: 0}
  end


  def search(urls, level)
    new_links = []

    urls.each do |lookup_url|
      @stats[:crawler] += 1

      request_uri = URI.parse(lookup_url)
      begin
        response = open(request_uri, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).read
      rescue
        # Can be 404, 500 etc
        next
      end

      # Strip out html tags to search content only
      if (text_only = response.gsub(/<\/?[^>]*>/, "")) && text_only.include?(term)
        sentence = text_only.split("\n").select { |l| l.include?(term) }.first
        @results << {url: lookup_url, text: sentence}
      end

      # Link deep
      if level < 2
        urls  = response.scan(/<a.+?href="(.+?)"/)
        # Find links and standarize them into full url
        new_links = urls
          .map { |l| l.first }
          .select { |l| l.start_with?(base_url) || l.start_with?("/") }
          .map { |l| l = "#{base_url}#{l}" if (l.start_with?("/") && !l.start_with?("//www")) ; l }
          .map { |l| l = "https:#{l}" if l.start_with?("//www") ; l }
      end
    end

    search(new_links, level + 1) if new_links.length > 0
  end

  def output
    puts "Crawled #{@stats[:crawler]} pages. Found #{@results.length} pages with the term ‘#{term}’"
    while r = @results.pop
      if r[:text].include?('.')
        r[:text] = r[:text].split(".").select { |s| s.include?(term) }.first
      end

      puts "#{r[:url]} => #{r[:text]}"
    end
  end

  def run
    # start
    # spawn_worker
    # @workers.each do |t| t.join end

    search([url], 0)
    output
  end

  private
  def links
    @links
  end
end

# TODO: parse argv
c = Crawler.new(ARGV[0], ARGV[1])
c.run
