# frozen_string_literal: true

# Per-listing messaging - sending a message. Reading the thread happens inline in
# listings_routes.rb's `GET /listings/:id` (the thread is part of the listing detail page, not
# its own route) - this router only owns the write.
#
# SECURITY: `can_message?` re-derives visibility from freshly-fetched `listings`/`proposals`
# documents on every request - a client's listing ownership, or a freelancer's *accepted*
# proposal on this specific listing - never from a hidden form field. See plan/build-plan.md
# "Messaging visibility" for the design rule this enforces (client + the one accepted
# freelancer, not every applicant).
class App < Sinatra::Base
  CONTENT_MAX_LENGTH = 2000

  post "/listings/:id/messages" do
    listing_id = params["id"]
    require_login!
    halt 404, erb(:"errors/not_found", layout: :layout) unless object_id?(listing_id)

    listing = with_access_token { |token| Mudbase::ListingsRepo.find(access_token: token, id: listing_id) }
    if listing.nil?
      flash_error("That listing no longer exists.")
      redirect "/"
    end

    accepted_freelancer_id = with_access_token do |token|
      Mudbase::ProposalsRepo.accepted_freelancer_id(access_token: token, listing_id: listing_id)
    end

    unless can_message?(listing, accepted_freelancer_id)
      flash_error("You don't have access to this conversation.")
      redirect "/listings/#{listing_id}"
    end

    content = params["content"].to_s.strip
    if content.empty? || content.length > CONTENT_MAX_LENGTH
      flash_error(content.empty? ? "Write a message before sending." : "Messages are limited to #{CONTENT_MAX_LENGTH} characters.")
      redirect "/listings/#{listing_id}"
    end

    with_access_token do |token|
      Mudbase::MessagesRepo.create!(
        access_token: token,
        attributes: { listingId: listing_id, senderId: @current_user[:id], senderName: current_user_name, content: content },
      )
    end

    redirect "/listings/#{listing_id}"
  end

  helpers do
    # @param listing [Hash] a freshly-fetched listing document (never trust a cached/hidden
    #   value for this - see the file header comment).
    # @param accepted_freelancer_id [String, nil] freshly-fetched from `proposals`, never from
    #   client input.
    def can_message?(listing, accepted_freelancer_id)
      return false unless logged_in?
      return true if client? && listing[:clientId] == @current_user[:id]

      freelancer? && accepted_freelancer_id == @current_user[:id]
    end
  end
end
