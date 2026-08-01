# frozen_string_literal: true

require "time"

# ERB helpers shared by every view.
module ViewHelpers
  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end

  def format_datetime(iso_string)
    return "" if iso_string.nil? || iso_string.to_s.empty?

    Time.parse(iso_string.to_s).strftime("%b %-d, %Y %-I:%M %p")
  rescue ArgumentError
    iso_string.to_s
  end

  # Compact "3m", "2h", "5d" style relative time - falls back to an absolute date once it's more
  # than a week old, mirroring the reference web app's `formatRelativeTime`.
  def format_relative(iso_string)
    return "" if iso_string.nil? || iso_string.to_s.empty?

    then_time = Time.parse(iso_string.to_s)
    seconds = (Time.now - then_time).to_i
    return "just now" if seconds < 5
    return "#{seconds}s" if seconds < 60
    return "#{seconds / 60}m" if seconds < 3600
    return "#{seconds / 3600}h" if seconds < 86_400
    return "#{seconds / 86_400}d" if seconds < 604_800

    then_time.strftime("%b %-d, %Y")
  rescue ArgumentError
    iso_string.to_s
  end

  def format_currency(amount)
    format("$%<amount>d", amount: amount.to_f.round)
  end

  def initials(name)
    parts = name.to_s.strip.split(/\s+/)
    return "?" if parts.empty?
    return parts.first[0].upcase if parts.length == 1

    "#{parts.first[0]}#{parts.last[0]}".upcase
  end

  LISTING_STATUS_LABELS = {
    "open" => "Open",
    "in_progress" => "In progress",
    "completed" => "Completed",
  }.freeze

  def listing_status_label(status)
    LISTING_STATUS_LABELS.fetch(status.to_s, status.to_s)
  end

  PROPOSAL_STATUS_LABELS = {
    "pending" => "Pending",
    "accepted" => "Accepted",
    "rejected" => "Rejected",
  }.freeze

  def proposal_status_label(status)
    PROPOSAL_STATUS_LABELS.fetch(status.to_s, status.to_s)
  end

  def proposal_status_class(status)
    "status-badge status-badge-#{status}"
  end
end
