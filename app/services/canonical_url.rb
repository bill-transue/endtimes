class CanonicalUrl
  TRACKING_PARAM = /\A(utm_|fbclid|gclid|mc_|icid|ref)\w*/i

  def self.call(url)
    new(url).to_s
  end

  def initialize(url)
    @raw = url.to_s.strip
  end

  def to_s
    uri = URI.parse(@raw)
    uri.fragment = nil
    if uri.query.present?
      kept = URI.decode_www_form(uri.query).reject { |key, _| key.match?(TRACKING_PARAM) }
      uri.query = kept.any? ? URI.encode_www_form(kept) : nil
    end
    uri.path = uri.path.chomp("/") if uri.path.present? && uri.path != "/"
    uri.to_s
  rescue URI::InvalidURIError
    @raw
  end
end
