# frozen_string_literal: true

require "json"

# Browse, detail, post, edit, and "my listings". Reads are public (a guest gets a silent
# anonymous session via `with_read_token` - see lib/session_helpers.rb); posting/editing require
# a real signed-in `client` account. Every mutating route re-derives ownership from a
# freshly-fetched listing document before ever calling Mudbase - never from a hidden form field -
# see `edit_listing_submit` below and plan/build-plan.md's IDOR note.
class App < Sinatra::Base
  TITLE_MAX_LENGTH = 120
  DESCRIPTION_MIN_LENGTH = 20
  DESCRIPTION_MAX_LENGTH = 4000
  CATEGORY_MAX_LENGTH = 60
  LISTING_STATUSES = %w[open in_progress completed].freeze

  get "/" do
    @page = [params["page"].to_i, 1].max
    @search = params["q"].to_s.strip
    @category = params["category"].to_s.strip
    @min_budget = params["min_budget"].to_s.strip
    @max_budget = params["max_budget"].to_s.strip

    min_value = parse_budget(@min_budget)
    max_value = parse_budget(@max_budget)

    if @search.empty?
      filter = {}
      filter[:category] = @category unless @category.empty?
      budget_filter = {}
      budget_filter["$gte"] = min_value if min_value
      budget_filter["$lte"] = max_value if max_value
      filter[:budget] = budget_filter unless budget_filter.empty?

      result = with_read_token do |token|
        Mudbase::ListingsRepo.list(access_token: token, filter: filter, page: @page, limit: Mudbase::ListingsRepo::PAGE_SIZE)
      end
      @listings = result[:data]
      @pagination = result[:pagination]
    else
      all_matches = with_read_token { |token| Mudbase::ListingsRepo.search(access_token: token, q: @search) }
      filtered = all_matches.select { |listing| matches_filters?(listing, @category, min_value, max_value) }
      total = filtered.length
      total_pages = [(total.to_f / Mudbase::ListingsRepo::PAGE_SIZE).ceil, 1].max
      start = (@page - 1) * Mudbase::ListingsRepo::PAGE_SIZE
      @listings = filtered[start, Mudbase::ListingsRepo::PAGE_SIZE] || []
      @pagination = { page: @page, limit: Mudbase::ListingsRepo::PAGE_SIZE, total: total, totalPages: total_pages, hasMore: @page < total_pages }
    end

    @categories = with_read_token { |token| Mudbase::ListingsRepo.category_sample(access_token: token) }
    erb :"listings/index"
  end

  get "/listings/new" do
    require_client!

    @listing = { title: "", description: "", budget: "", category: "" }
    @form_action = "/listings"
    @form_title = "Post a new listing"
    @submit_label = "Post listing"
    @show_status = false
    erb :"listings/form"
  end

  post "/listings" do
    require_client!

    values = extract_listing_form(params)
    errors = validate_listing_form(values)
    if errors.any?
      @listing = values
      @form_action = "/listings"
      @form_title = "Post a new listing"
      @submit_label = "Post listing"
      @show_status = false
      show_error_now(errors.join(" "))
      halt erb(:"listings/form")
    end

    created = with_access_token do |token|
      Mudbase::ListingsRepo.create!(
        access_token: token,
        attributes: listing_attributes(values).merge(
          status: "open",
          clientId: @current_user[:id],
          clientName: current_user_name,
        ),
      )
    end

    flash_notice("Listing posted.")
    redirect "/listings/#{created[:_id]}"
  end

  get "/listings/mine" do
    require_client!

    @page = [params["page"].to_i, 1].max
    result = with_access_token do |token|
      Mudbase::ListingsRepo.list(
        access_token: token,
        filter: { clientId: @current_user[:id] },
        page: @page,
        limit: Mudbase::ListingsRepo::PAGE_SIZE,
      )
    end
    @listings = result[:data]
    @pagination = result[:pagination]

    listing_ids = @listings.map { |l| l[:_id] }
    @proposal_counts = with_access_token do |token|
      Mudbase::ProposalsRepo.count_by_listing_ids(access_token: token, listing_ids: listing_ids)
    end

    erb :"listings/mine"
  end

  get "/listings/:id" do
    id = params["id"]
    halt 404, erb(:"errors/not_found", layout: :layout) unless object_id?(id)

    @listing = with_read_token { |token| Mudbase::ListingsRepo.find(access_token: token, id: id) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless @listing

    @is_owning_client = client? && @current_user[:id] == @listing[:clientId]
    @is_freelancer = freelancer?

    @own_proposal = nil
    if @is_freelancer
      @own_proposal = with_access_token do |token|
        Mudbase::ProposalsRepo.find_own(access_token: token, listing_id: id, freelancer_id: @current_user[:id])
      end
    end

    @proposals = []
    @proposals = with_access_token { |token| Mudbase::ProposalsRepo.for_listing(access_token: token, listing_id: id) } if @is_owning_client

    accepted_freelancer_id = with_read_token { |token| Mudbase::ProposalsRepo.accepted_freelancer_id(access_token: token, listing_id: id) }
    # Same `can_message?` helper the POST /listings/:id/messages write route re-derives its
    # decision from (see app/routes/messages_routes.rb) - one rule, not two copies that could
    # silently drift out of sync.
    @can_message = can_message?(@listing, accepted_freelancer_id)

    @messages = []
    @messages = with_access_token { |token| Mudbase::MessagesRepo.for_listing(access_token: token, listing_id: id) } if @can_message

    erb :"listings/show"
  end

  get "/listings/:id/edit" do
    id = params["id"]
    require_client!
    halt 404, erb(:"errors/not_found", layout: :layout) unless object_id?(id)

    listing = with_access_token { |token| Mudbase::ListingsRepo.find(access_token: token, id: id) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless listing

    # IDOR guard: re-derive ownership from the document Mudbase just returned - never trust a
    # route param alone to imply the current user owns this listing.
    unless listing[:clientId] == @current_user[:id]
      flash_error("Only the client who posted this listing can edit it.")
      redirect "/listings/#{id}"
    end

    @listing = { title: listing[:title], description: listing[:description], budget: listing[:budget], category: listing[:category] }
    @listing_status = listing[:status]
    @form_action = "/listings/#{id}"
    @form_title = "Edit listing"
    @submit_label = "Save changes"
    @show_status = true
    erb :"listings/form"
  end

  post "/listings/:id" do
    id = params["id"]
    require_client!
    halt 404, erb(:"errors/not_found", layout: :layout) unless object_id?(id)

    listing = with_access_token { |token| Mudbase::ListingsRepo.find(access_token: token, id: id) }
    halt 404, erb(:"errors/not_found", layout: :layout) unless listing

    # IDOR guard (see comment in the GET /edit handler above): re-verify ownership against the
    # freshly-fetched document, not the hidden route param, before any write is attempted.
    unless listing[:clientId] == @current_user[:id]
      flash_error("Only the client who posted this listing can edit it.")
      redirect "/listings/#{id}"
    end

    values = extract_listing_form(params)
    status = params["status"].to_s
    status = listing[:status] unless LISTING_STATUSES.include?(status)

    errors = validate_listing_form(values)
    if errors.any?
      @listing = values
      @listing_status = status
      @form_action = "/listings/#{id}"
      @form_title = "Edit listing"
      @submit_label = "Save changes"
      @show_status = true
      show_error_now(errors.join(" "))
      halt erb(:"listings/form")
    end

    with_access_token do |token|
      Mudbase::ListingsRepo.update!(access_token: token, id: id, attributes: listing_attributes(values).merge(status: status))
    end

    flash_notice("Listing updated.")
    redirect "/listings/#{id}"
  end

  helpers do
    def parse_budget(raw)
      return nil if raw.nil? || raw.to_s.strip.empty?

      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    # Rebuilds the browse page's query string, preserving the current search/category/budget
    # filters while overriding whichever params are passed in (used by pagination links).
    def build_query(overrides = {})
      params = { "q" => @search, "category" => @category, "min_budget" => @min_budget, "max_budget" => @max_budget, "page" => @page }
      overrides.each { |key, value| params[key.to_s] = value }
      params.reject { |_, v| v.nil? || v.to_s.empty? }.map { |k, v| "#{Rack::Utils.escape(k)}=#{Rack::Utils.escape(v.to_s)}" }.join("&")
    end

    # Client-side application of the category/budget filters over a search result batch - the
    # dedicated search endpoint only takes a keyword and doesn't accept structured filters
    # alongside it. Mirrors the reference web app's `matchesFilters`.
    def matches_filters?(listing, category, min_budget, max_budget)
      return false if !category.empty? && listing[:category] != category
      return false if min_budget && listing[:budget].to_f < min_budget
      return false if max_budget && listing[:budget].to_f > max_budget

      true
    end

    def extract_listing_form(params)
      {
        title: params["title"].to_s.strip,
        description: params["description"].to_s.strip,
        budget: params["budget"].to_s.strip,
        category: params["category"].to_s.strip,
      }
    end

    def validate_listing_form(values)
      errors = []
      errors << "Title must be at least 3 characters." if values[:title].length < 3
      errors << "Keep the title under #{TITLE_MAX_LENGTH} characters." if values[:title].length > TITLE_MAX_LENGTH
      errors << "Description must be at least #{DESCRIPTION_MIN_LENGTH} characters." if values[:description].length < DESCRIPTION_MIN_LENGTH
      errors << "Keep the description under #{DESCRIPTION_MAX_LENGTH} characters." if values[:description].length > DESCRIPTION_MAX_LENGTH
      budget = parse_budget(values[:budget])
      errors << "Budget must be greater than 0." if budget.nil? || budget <= 0
      errors << "Keep the category under #{CATEGORY_MAX_LENGTH} characters." if values[:category].length > CATEGORY_MAX_LENGTH
      errors
    end

    def listing_attributes(values)
      attrs = {
        title: values[:title],
        description: values[:description],
        budget: parse_budget(values[:budget]),
      }
      attrs[:category] = values[:category].empty? ? nil : values[:category]
      attrs
    end
  end
end
