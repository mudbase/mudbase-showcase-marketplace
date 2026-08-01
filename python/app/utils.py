"""Small formatting helpers. Ported from the sibling mudbase-showcase-social/
mudbase-showcase-kanban Python ports' app/utils.py, plus `is_object_id` — a
direct port of ../web/src/lib/utils.ts::isObjectId, used the same way here:
Mudbase's query sanitizer rejects (and security-alerts on) any top-level
filter field ending in "Id" that isn't a real 24-hex-char ObjectId, so every
call site that builds a `...Id` filter guards it with this check first
rather than sending a possibly-invalid id straight to the API.
"""

import re
from datetime import datetime

_OBJECT_ID_PATTERN = re.compile(r"^[a-f0-9]{24}$", re.IGNORECASE)


def is_object_id(value: str | None) -> bool:
    return value is not None and bool(_OBJECT_ID_PATTERN.match(value))


def _parse(value: datetime | str) -> datetime | None:
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return value


def format_date(value: datetime | str | None) -> str:
    """Formats an ISO timestamp (or already-parsed datetime) for display."""
    if value is None:
        return ""
    parsed = _parse(value)
    if parsed is None:
        return str(value)
    return parsed.strftime("%b %-d, %Y, %-I:%M %p")


def initial(name: str | None) -> str:
    """Up to two initials of a display name, uppercased, for the avatar
    circle. Falls back to "?" for an empty/missing name. Mirrors
    ../web/src/lib/utils.ts::initials."""
    stripped = (name or "").strip()
    if not stripped:
        return "?"
    parts = [p for p in stripped.split() if p]
    if not parts:
        return "?"
    first = parts[0][0]
    last = parts[-1][0] if len(parts) > 1 else ""
    return (first + last).upper()


def relative_time(value: datetime | str | None) -> str:
    """A short "2h ago"-style label, falling back to `format_date` for
    anything older than a week (where a relative label stops being useful).
    Mirrors ../web/src/lib/utils.ts::formatRelativeTime."""
    if value is None:
        return ""
    parsed = _parse(value)
    if parsed is None:
        return str(value)

    now = datetime.now(parsed.tzinfo) if parsed.tzinfo else datetime.now()
    delta_seconds = (now - parsed).total_seconds()
    if delta_seconds < 60:
        return "just now"
    if delta_seconds < 3600:
        minutes = int(delta_seconds // 60)
        return f"{minutes}m ago"
    if delta_seconds < 86400:
        hours = int(delta_seconds // 3600)
        return f"{hours}h ago"
    if delta_seconds < 604800:
        days = int(delta_seconds // 86400)
        return f"{days}d ago"
    return format_date(parsed)


def format_currency(amount: float) -> str:
    """USD, no decimals - mirrors ../web/src/lib/utils.ts::formatCurrency."""
    return f"${amount:,.0f}"
