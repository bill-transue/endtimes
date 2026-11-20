require "test_helper"

class AllowedHostsTest < ActiveSupport::TestCase
  test "includes onrender and custom domains by default" do
    hosts = AllowedHosts.from_env({})

    assert_includes hosts, "endtimesfeed.com"
    assert_includes hosts, "www.endtimesfeed.com"
    assert hosts.any? { |host| host.is_a?(Regexp) && host.match?("endtimes.onrender.com") }
  end

  test "adds render hostname and comma-separated APP_HOSTS" do
    hosts = AllowedHosts.from_env(
      "RENDER_EXTERNAL_HOSTNAME" => "endtimes.onrender.com",
      "APP_HOSTS" => " feed.example.com, ,other.example.com "
    )

    assert_includes hosts, "endtimes.onrender.com"
    assert_includes hosts, "feed.example.com"
    assert_includes hosts, "other.example.com"
    assert_not_includes hosts, ""
  end
end
