# frozen_string_literal: true

module Mudbase
  # Fails fast at boot with a clear message rather than surfacing a confusing
  # nil-related error deep inside a request handler later.
  class MissingEnvError < StandardError
    def initialize(name)
      super("Missing required environment variable: #{name}")
    end
  end

  module Config
    def self.require_env(name)
      value = ENV[name]
      raise MissingEnvError, name if value.nil? || value.empty?

      value
    end

    def self.base_url
      ENV.fetch("MUDBASE_URL", "https://cloud.mudbase.dev")
    end

    def self.project_id
      require_env("MUDBASE_PROJECT_ID")
    end

    def self.listings_collection_id
      require_env("LISTINGS_COLLECTION_ID")
    end

    def self.proposals_collection_id
      require_env("PROPOSALS_COLLECTION_ID")
    end

    def self.messages_collection_id
      require_env("MESSAGES_COLLECTION_ID")
    end

    # The listings collection's *slug* - distinct from its ObjectId above. The dedicated
    # search endpoint's `collections` query param matches on slug, not on the collection's
    # `_id` (see lib/mudbase/listings_repo.rb#search).
    def self.listings_collection_slug
      ENV.fetch("LISTINGS_COLLECTION_SLUG", "listings")
    end

    def self.session_secret
      require_env("SESSION_SECRET")
    end
  end
end
