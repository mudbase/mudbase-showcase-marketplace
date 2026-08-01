# frozen_string_literal: true

require "json"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `messages` - a listing's message thread. Visibility (who may read/send)
  # is computed by this app's own routes from freshly-fetched `listings`/`proposals` documents
  # (see `app/routes/messages_routes.rb`'s `can_message?`) before this module is ever called -
  # see plan/build-plan.md "Messaging visibility".
  module MessagesRepo
    LIST_LIMIT = 100

    def self.for_listing(access_token:, listing_id:, limit: LIST_LIMIT)
      opts = { filter: { listingId: listing_id }.to_json, sort: "createdAt", limit: limit }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.messages_collection_id,
        opts,
      )
      data[:data] || []
    end

    def self.create!(access_token:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.messages_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end
  end
end
