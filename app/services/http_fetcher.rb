require "net/http"
require "uri"
require "json"

class HttpFetcher
  DEFAULT_HEADERS = {
    "User-Agent" => "EndTimesBiblicalReader/1.0 (+https://github.com)",
    "Accept" => "*/*"
  }.freeze

  def self.get(url, params: {}, headers: {}, timeout: 15)
    new.get(url, params: params, headers: headers, timeout: timeout)
  end

  def get(url, params: {}, headers: {}, timeout: 15)
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s) + params.to_a) if params.present?
    perform(:get, uri, headers: headers, timeout: timeout)
  end

  def post_json(url, body:, headers: {}, timeout: 30)
    uri = URI.parse(url)
    perform(:post, uri, headers: headers.merge("Content-Type" => "application/json"), body: JSON.generate(body), timeout: timeout)
  end

  private
    def perform(method, uri, headers:, timeout:, body: nil, redirects: 0)
      raise "Too many redirects" if redirects > 3

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout
      http.read_timeout = timeout

      request = (method == :post) ? Net::HTTP::Post.new(uri.request_uri) : Net::HTTP::Get.new(uri.request_uri)
      DEFAULT_HEADERS.merge(headers).each { |key, value| request[key] = value }
      request.body = body if body

      response = http.request(request)
      case response
      when Net::HTTPRedirection
        location = response["location"]
        raise "Redirect without location" if location.blank?
        next_uri = URI.parse(location)
        next_uri = uri + location if next_uri.relative?
        perform(method, next_uri, headers: headers, timeout: timeout, body: body, redirects: redirects + 1)
      else
        response
      end
    end
end
