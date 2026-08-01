# frozen_string_literal: true

require "json"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `listings` - public (authenticated-or-guest token) read, `client`-role
  # create/update. Mudbase's collection permissions are collection-level, not automatically
  # document-level scoped (see plan/build-plan.md "RBAC matrix"), so ownership on update/edit is
  # re-verified by this app's own routes against the *fetched* document before ever calling
  # `update!` here - see `app/routes/listings_routes.rb`. All calls force
  # `debug_return_type: "Object"` (see ClientFactory) so every real document field survives
  # typed deserialization.
  module ListingsRepo
    # Real platform ceiling on the generated SDK's `DataApi#list_data` (`limit <= 100`,
    # client-side-validated, confirmed live by the sibling kanban/social Ruby ports' own builds).
    LIST_LIMIT = 100
    PAGE_SIZE = 12
    CATEGORY_SAMPLE_LIMIT = 100
    SEARCH_LIMIT = 50

    # @return [Hash] `{ data: [Hash], pagination: Hash }` exactly as the wire response does.
    def self.list(access_token:, filter: {}, sort: "-createdAt", page: 1, limit: PAGE_SIZE)
      opts = { sort: sort, page: page, limit: limit }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      opts[:filter] = filter.to_json unless filter.empty?
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.listings_collection_id,
        opts,
      )
      { data: data[:data] || [], pagination: data[:pagination] || {} }
    end

    def self.find(access_token:, id:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).get_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.listings_collection_id,
        id,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    rescue MudbaseSDK::ApiError => e
      raise e unless Mudbase::ApiFailure.from(e).status == 404

      nil
    end

    def self.create!(access_token:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).create_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.listings_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.update!(access_token:, id:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).update_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.listings_collection_id,
        id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    # Batched lookup for the listing titles referenced across a set of ids (e.g. a freelancer's
    # "my proposals" page) - one query instead of an N+1 per proposal. Mirrors the reference web
    # app's `listingsById` in `src/app/proposals/page.tsx`.
    def self.find_many(access_token:, ids:)
      return [] if ids.empty?

      opts = { filter: { _id: { "$in" => ids } }.to_json, limit: LIST_LIMIT }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.listings_collection_id,
        opts,
      )
      data[:data] || []
    end

    # A lightweight, unfiltered sample used only to populate the category filter dropdown -
    # avoids a dedicated "distinct categories" endpoint that Mudbase's data API doesn't expose.
    # Mirrors the reference web app's `categorySample` query.
    def self.category_sample(access_token:)
      opts = { limit: CATEGORY_SAMPLE_LIMIT }.merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.listings_collection_id,
        opts,
      )
      (data[:data] || []).filter_map { |doc| doc[:category] }.uniq.sort
    end

    # Server-side keyword search across a collection's string fields (title/description/...) -
    # the real search surface. The collection-data `filter` param cannot do substring search:
    # `$regex` (and `$text`'s `$search`) are on the deployed query sanitizer's
    # dangerous-operator blocklist and always 400 (see plan/build-plan.md). This endpoint builds
    # its own regex server-side, so it isn't subject to that block. Only accepts a keyword - the
    # caller applies category/budget filters and pagination client-side over this batch.
    def self.search(access_token:, q:, limit: SEARCH_LIMIT)
      opts = { collections: Mudbase::Config.listings_collection_slug, limit: limit }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.search_api(access_token: access_token).search_data_with_http_info(
        Mudbase::Config.project_id,
        q,
        opts,
      )
      results = data[:results] || []
      first = results.first || {}
      first[:results] || []
    end
  end
end
