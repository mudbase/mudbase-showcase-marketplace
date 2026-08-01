# frozen_string_literal: true

require_relative "mudbase/errors"
require_relative "mudbase/auth_service"

# Sinatra helpers for reading/writing the signed-in user's state, plus a silent anonymous "guest
# read" session so public pages (listings browse + detail) resolve without ever prompting a
# visitor to sign in - every collection read on this backend requires *some* authenticated JWT
# (mirrors the sibling `mudbase-showcase-social` port's own finding). The Mudbase-issued JWTs
# are held only inside the Rack session cookie (encrypted + signed + httponly via
# `Rack::Session::Cookie`, configured in app.rb) - never rendered into a page or exposed to
# client-side JavaScript.
#
# Refresh-token rotation: every route that calls Mudbase routes its access token through either
# `with_access_token` (real user, required - redirects to /login if not signed in) or
# `with_read_token` (real user if signed in, otherwise a guest session - never redirects). Both
# proactively refresh a token that's about to expire and reactively refresh-and-retry exactly
# once on a real 401 from the server.
module SessionHelpers
  TOKEN_REFRESH_MARGIN_SECONDS = 60
  OBJECT_ID_PATTERN = /\A[a-f0-9]{24}\z/i.freeze

  # Mudbase's query sanitizer rejects any top-level filter field ending in "Id" that isn't a
  # real 24-hex-char ObjectId - guard every synthesized/user-supplied id before it ever reaches
  # a filter (see plan/build-plan.md).
  def object_id?(value)
    value.is_a?(String) && OBJECT_ID_PATTERN.match?(value)
  end

  def store_auth_session!(auth_session)
    session[:token] = auth_session.token
    session[:refresh_token] = auth_session.refresh_token
    session[:expires_at] = Time.now.to_i + auth_session.expires_in.to_i
    session[:user] = auth_session.user
  end

  def clear_auth_session!
    session.delete(:token)
    session.delete(:refresh_token)
    session.delete(:expires_at)
    session.delete(:user)
  end

  def access_token
    session[:token]
  end

  def current_user
    session[:user]
  end

  # A real, role-carrying account - distinct from the always-present anonymous guest session
  # established by `ensure_guest_session!`. Mirrors the reference web app's
  # `useAuth().isAuthenticated`.
  def logged_in?
    !current_user.nil? && current_user[:isAnonymous] != true && !current_user[:customRole].nil?
  end

  # Wraps every Mudbase call that needs the signed-in user's own access token (writes: posting a
  # listing, submitting/accepting/rejecting a proposal, sending a message). If no refresh token
  # is stored, or the refresh token itself is rejected (expired/already rotated away/revoked),
  # the original `MudbaseSDK::ApiError` propagates to app.rb's global handler, which logs the
  # session out.
  def with_access_token
    refresh_access_token! if token_expiring_soon?
    yield session[:token]
  rescue MudbaseSDK::ApiError => e
    failure = Mudbase::ApiFailure.from(e)
    raise e unless failure.status == 401
    raise e unless refresh_access_token!

    yield session[:token]
  end

  def token_expiring_soon?
    session[:expires_at].nil? || Time.now.to_i >= session[:expires_at] - TOKEN_REFRESH_MARGIN_SECONDS
  end

  # @return [Boolean] whether the refresh succeeded and `session[:token]` is now fresh.
  def refresh_access_token!
    return false unless session[:refresh_token]

    auth_session = Mudbase::AuthService.refresh!(session[:refresh_token])
    session[:token] = auth_session.token
    session[:refresh_token] = auth_session.refresh_token
    session[:expires_at] = Time.now.to_i + auth_session.expires_in.to_i
    true
  rescue Mudbase::AuthError
    false
  end

  # ── Guest (anonymous) read session ──────────────────────────────────────────────────────

  def guest_token_expiring_soon?
    session[:guest_expires_at].nil? || Time.now.to_i >= session[:guest_expires_at] - TOKEN_REFRESH_MARGIN_SECONDS
  end

  def clear_guest_session!
    session.delete(:guest_token)
    session.delete(:guest_refresh_token)
    session.delete(:guest_expires_at)
  end

  # Mints (or refreshes) a silent anonymous session and stores it in the Rack session, entirely
  # separate from any real signed-in user's tokens. A logged-in user never needs this - reads go
  # through their own access token via `with_read_token` below.
  def ensure_guest_session!
    return if session[:guest_token] && !guest_token_expiring_soon?

    if session[:guest_refresh_token] && !session[:guest_token].nil?
      begin
        auth_session = Mudbase::AuthService.refresh!(session[:guest_refresh_token])
        session[:guest_token] = auth_session.token
        session[:guest_refresh_token] = auth_session.refresh_token
        session[:guest_expires_at] = Time.now.to_i + auth_session.expires_in.to_i
        return
      rescue Mudbase::AuthError
        clear_guest_session!
      end
    end

    auth_session = Mudbase::AuthService.login_anonymous!
    session[:guest_token] = auth_session.token
    session[:guest_refresh_token] = auth_session.refresh_token
    session[:guest_expires_at] = Time.now.to_i + auth_session.expires_in.to_i
  end

  # Wraps every Mudbase call that only needs *some* authenticated token for a public read - the
  # signed-in user's own token if logged in, otherwise a silent anonymous guest session. Retries
  # exactly once on a real 401, minting a brand-new guest session if the guest one itself was
  # rejected.
  def with_read_token(&block)
    return with_access_token(&block) if logged_in?

    ensure_guest_session!
    begin
      yield session[:guest_token]
    rescue MudbaseSDK::ApiError => e
      failure = Mudbase::ApiFailure.from(e)
      raise e unless failure.status == 401

      clear_guest_session!
      ensure_guest_session!
      yield session[:guest_token]
    end
  end

  # ── Role helpers (RBAC matrix, plan/build-plan.md) ──────────────────────────────────────
  # Mudbase's own collection permissions are collection-level, not automatically document-level
  # scoped - these helpers are this app's own *additional* server-side gate on top of that. The
  # critical document-level checks (does *this* listing/proposal belong to the current user)
  # live in the route handlers themselves, re-derived from a freshly-fetched document every
  # time - never from a hidden form/query field - see `app/routes/listings_routes.rb` and
  # `app/routes/proposals_routes.rb`.

  def current_role
    current_user && current_user[:customRole]
  end

  def client?
    logged_in? && current_role == "client"
  end

  def freelancer?
    logged_in? && current_role == "freelancer"
  end

  def require_login!
    return if logged_in?

    session[:return_to] = request.path_info
    redirect "/login"
  end

  # Server-side gate for posting/editing a listing - client role only. Ownership of a *specific*
  # listing (for edit) is a separate, additional check performed by the route itself.
  def require_client!
    require_login!
    return if client?

    flash_error("Sign in with a client account to do that.")
    redirect back_or("/")
  end

  # Server-side gate for submitting a proposal - freelancer role only.
  def require_freelancer!
    require_login!
    return if freelancer?

    flash_error("Sign in with a freelancer account to do that.")
    redirect back_or("/")
  end

  def consume_return_to
    session.delete(:return_to) || "/"
  end

  # For "set then redirect" flows: written to the session so the *next* request's `before`
  # filter (which runs before the route body, and so before any `flash_error`/`flash_notice`
  # call made this request) can pick it up via pop_flash_notice/pop_flash_error.
  def flash_notice(message)
    session[:flash_notice] = message
  end

  def flash_error(message)
    session[:flash_error] = message
  end

  def pop_flash_notice
    session.delete(:flash_notice)
  end

  def pop_flash_error
    session.delete(:flash_error)
  end

  # For "validate, then re-render the same page in this same response" flows (a failed
  # login/register/form submission). `@flash_error`/`@flash_notice` are already populated for
  # this request by the `before` filter *before* the route body runs, so a form-validation
  # failure has to set the ivar directly - writing to session here would only become visible on
  # the *following* request, leaving this response's re-rendered form with no visible error.
  def show_error_now(message)
    @flash_error = message
  end

  def show_notice_now(message)
    @flash_notice = message
  end
end
