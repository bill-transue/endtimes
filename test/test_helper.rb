ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    parallelize(workers: :number_of_processors)

    def create_story(attrs = {})
      Story.create!(
        {
          url: "https://example.com/#{SecureRandom.hex(4)}",
          title: "A cabinet scandal over hidden contracts",
          description: "Prosecutors described bribes and greed at the ministry.",
          source_name: "Reuters",
          source_kind: :rss,
          status: :ingested,
          published_at: Time.current,
          raw_payload: { "excerpt" => "bribes and greed" }
        }.merge(attrs)
      )
    end

    def seed_verse!(book:, chapter:, verse:, text: "Sample WEB text.")
      BibleVerse.create!(book: book, chapter: chapter, verse: verse, text: text)
    end

    setup do
      Story.destroy_all
    end
  end
end
