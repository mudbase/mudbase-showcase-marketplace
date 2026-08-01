# frozen_string_literal: true

# Proposal submission (freelancer), accept/reject (owning client), and "my proposals"
# (freelancer).
#
# SECURITY - IDOR guard on accept/reject: `POST /proposals/:id/accept` and `.../reject` never
# trust a hidden form/query field to determine whether the current user may act on a given
# proposal. Every request re-fetches the proposal by its real `:id`, then re-fetches the listing
# it references, then checks `listing[:clientId] == @current_user[:id]` against those
# freshly-loaded documents before ever calling `ProposalsRepo.update!`. A sibling C# Events port
# shipped a booking-cancellation handler that trusted a hidden-form ownership flag instead of
# re-deriving it server-side - `set_proposal_status!` below is written specifically to avoid
# that class of bug.
class App < Sinatra::Base
  COVER_LETTER_MIN_LENGTH = 20
  COVER_LETTER_MAX_LENGTH = 4000

  post "/listings/:id/proposals" do
    listing_id = params["id"]
    require_freelancer!
    halt 404, erb(:"errors/not_found", layout: :layout) unless object_id?(listing_id)

    listing = with_access_token { |token| Mudbase::ListingsRepo.find(access_token: token, id: listing_id) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless listing

    existing = with_access_token do |token|
      Mudbase::ProposalsRepo.find_own(access_token: token, listing_id: listing_id, freelancer_id: @current_user[:id])
    end
    if existing
      flash_error("You've already submitted a proposal for this listing.")
      redirect "/listings/#{listing_id}"
    end

    cover_letter = params["cover_letter"].to_s.strip
    proposed_rate = parse_budget(params["proposed_rate"])

    errors = []
    errors << "Cover letter must be at least #{COVER_LETTER_MIN_LENGTH} characters." if cover_letter.length < COVER_LETTER_MIN_LENGTH
    errors << "Keep the cover letter under #{COVER_LETTER_MAX_LENGTH} characters." if cover_letter.length > COVER_LETTER_MAX_LENGTH
    errors << "Proposed rate must be greater than 0." if proposed_rate.nil? || proposed_rate <= 0
    if errors.any?
      flash_error(errors.join(" "))
      redirect "/listings/#{listing_id}"
    end

    with_access_token do |token|
      Mudbase::ProposalsRepo.create!(
        access_token: token,
        attributes: {
          listingId: listing_id,
          freelancerId: @current_user[:id],
          freelancerName: current_user_name,
          coverLetter: cover_letter,
          proposedRate: proposed_rate,
          status: "pending",
        },
      )
    end

    flash_notice("Proposal submitted.")
    redirect "/listings/#{listing_id}"
  end

  post "/proposals/:id/accept" do
    set_proposal_status!(params["id"], "accepted")
  end

  post "/proposals/:id/reject" do
    set_proposal_status!(params["id"], "rejected")
  end

  get "/proposals" do
    require_freelancer!

    @page = [params["page"].to_i, 1].max
    result = with_access_token do |token|
      Mudbase::ProposalsRepo.for_freelancer(access_token: token, freelancer_id: @current_user[:id], page: @page)
    end
    @proposals = result[:data]
    @pagination = result[:pagination]

    listing_ids = @proposals.map { |p| p[:listingId] }.uniq
    listings = with_access_token { |token| Mudbase::ListingsRepo.find_many(access_token: token, ids: listing_ids) }
    @listings_by_id = listings.each_with_object({}) { |listing, memo| memo[listing[:_id]] = listing }

    erb :"proposals/mine"
  end

  helpers do
    # @param proposal_id [String] the `:id` route param - untrusted input, never assumed to
    #   belong to the current user without the re-fetch-and-verify sequence below.
    # @param status ["accepted", "rejected"]
    def set_proposal_status!(proposal_id, status)
      require_login!
      halt 404, erb(:"errors/not_found", layout: :layout) unless object_id?(proposal_id)

      proposal = with_access_token { |token| Mudbase::ProposalsRepo.find(access_token: token, id: proposal_id) }
      if proposal.nil?
        flash_error("That proposal no longer exists.")
        redirect "/"
      end

      # Re-derive the listing this proposal belongs to from the proposal document Mudbase just
      # returned (never from a route param or hidden field), then re-derive ownership from that
      # freshly-fetched listing - the actual IDOR guard.
      listing = with_access_token { |token| Mudbase::ListingsRepo.find(access_token: token, id: proposal[:listingId]) }
      if listing.nil?
        flash_error("That listing no longer exists.")
        redirect "/"
      end

      unless client? && listing[:clientId] == @current_user[:id]
        flash_error("Only the client who posted this listing can review its proposals.")
        redirect "/listings/#{listing[:_id]}"
      end

      with_access_token { |token| Mudbase::ProposalsRepo.update!(access_token: token, id: proposal_id, attributes: { status: status }) }
      flash_notice("Proposal #{status}.")
      redirect "/listings/#{listing[:_id]}"
    end
  end
end
