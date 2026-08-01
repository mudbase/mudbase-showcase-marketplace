"""Shared Jinja2Templates instance + custom filters, importable by every
router without risking a circular import with main.py."""

from pathlib import Path

from fastapi.templating import Jinja2Templates

from app.schemas.listing import listing_status_label
from app.schemas.proposal import proposal_status_label
from app.utils import format_currency, format_date, initial, relative_time

TEMPLATES_DIR = Path(__file__).parent / "templates"

templates = Jinja2Templates(directory=str(TEMPLATES_DIR))
templates.env.filters["date"] = format_date
templates.env.filters["relative_time"] = relative_time
templates.env.filters["initial"] = initial
templates.env.filters["currency"] = format_currency
templates.env.filters["listing_status"] = listing_status_label
templates.env.filters["proposal_status"] = proposal_status_label
