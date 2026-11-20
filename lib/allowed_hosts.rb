module AllowedHosts
  DEFAULT = [
    /.*\.onrender\.com/,
    "endtimesfeed.com",
    "www.endtimesfeed.com"
  ].freeze

  def self.from_env(env = ENV)
    extra = [ env["RENDER_EXTERNAL_HOSTNAME"], *env.fetch("APP_HOSTS", "").split(",") ]
    DEFAULT + extra.filter_map { |host| host&.strip.presence }.uniq
  end
end
