# frozen_string_literal: true

require "json"
require "mudbase_sdk"
require_relative "client_factory"
require_relative "config"

module Mudbase
  # Thin repository over `proposals`. Mudbase's collection permissions are collection-level, not
  # automatically document-level scoped (see plan/build-plan.md "RBAC matrix"), so this app's
  # own routes re-verify ownership against the *fetched* document (never a hidden form/query
  # value) before ever calling `update!` here - see `app/routes/proposals_routes.rb`'s accept/
  # reject handlers, which re-derive `proposal.freelancerId`/the owning listing's `clientId` from
  # freshly-fetched documents rather than trusting anything the request supplied. All calls
  # force `debug_return_type: "Object"` (see ClientFactory) so every real document field
  # survives typed deserialization.
  module ProposalsRepo
    LIST_LIMIT = 100
    PAGE_SIZE = 10

    def self.for_listing(access_token:, listing_id:, limit: LIST_LIMIT)
      opts = { filter: { listingId: listing_id }.to_json, sort: "-createdAt", limit: limit }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.proposals_collection_id,
        opts,
      )
      data[:data] || []
    end

    # A freelancer's own proposal on a given listing, if any - determines whether the listing
    # detail page shows the submission form or the freelancer's existing status. Mirrors the
    # reference web app's `ownProposal` query.
    def self.find_own(access_token:, listing_id:, freelancer_id:)
      opts = { filter: { listingId: listing_id, freelancerId: freelancer_id }.to_json, limit: 1 }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.proposals_collection_id,
        opts,
      )
      (data[:data] || []).first
    end

    # Whichever proposal (if any) has been accepted on this listing - decides who besides the
    # client can see and use the message thread (see plan/build-plan.md "Messaging visibility").
    def self.accepted_freelancer_id(access_token:, listing_id:)
      opts = { filter: { listingId: listing_id, status: "accepted" }.to_json, limit: 1 }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.proposals_collection_id,
        opts,
      )
      first = (data[:data] || []).first
      first && first[:freelancerId]
    end

    def self.find(access_token:, id:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).get_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.proposals_collection_id,
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
        Mudbase::Config.proposals_collection_id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.update!(access_token:, id:, attributes:)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).update_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.proposals_collection_id,
        id,
        attributes,
        Mudbase::ClientFactory::OBJECT_RESPONSE,
      )
      data[:data]
    end

    def self.for_freelancer(access_token:, freelancer_id:, page: 1, limit: PAGE_SIZE)
      opts = { filter: { freelancerId: freelancer_id }.to_json, sort: "-createdAt", page: page, limit: limit }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.proposals_collection_id,
        opts,
      )
      { data: data[:data] || [], pagination: data[:pagination] || {} }
    end

    # One batched query for proposal counts across every listing on a page, instead of an N+1
    # query per listing. Mirrors the reference web app's `proposalCounts` in
    # `src/app/listings/mine/page.tsx`.
    def self.count_by_listing_ids(access_token:, listing_ids:)
      return {} if listing_ids.empty?

      opts = { filter: { listingId: { "$in" => listing_ids } }.to_json, limit: LIST_LIMIT }
        .merge(Mudbase::ClientFactory::OBJECT_RESPONSE)
      data, = Mudbase::ClientFactory.data_api(access_token: access_token).list_data_with_http_info(
        Mudbase::Config.project_id,
        Mudbase::Config.proposals_collection_id,
        opts,
      )
      counts = Hash.new(0)
      (data[:data] || []).each { |doc| counts[doc[:listingId]] += 1 if doc[:listingId] }
      counts
    end
  end
end
