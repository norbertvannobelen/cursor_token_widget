"""Display rules shared with the macOS app."""

from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone


def round_half_away(value: float) -> int:
    if value >= 0:
        return int(math.floor(value + 0.5))
    return int(math.ceil(value - 0.5))


def format_percent(value: float | None) -> str:
    if value is None or not math.isfinite(value):
        return "—"
    return f"{round_half_away(value)}%"


def bar_fraction(value: float | None) -> float:
    if value is None or not math.isfinite(value):
        return 0.0
    return min(max(value, 0.0), 100.0) / 100.0


def exceeds_warning(value: float | None) -> bool:
    """A bar turns red once the displayed percent is above 90."""
    if value is None or not math.isfinite(value):
        return False
    return round_half_away(value) > 90


def percent_of_limit(used: int | None, limit: int | None) -> float | None:
    if limit is None or limit <= 0:
        return None
    return (used or 0) / limit * 100.0


def format_cents(cents: int | None) -> str:
    if cents is None:
        return "—"
    sign = "-" if cents < 0 else ""
    absolute = abs(cents)
    if absolute % 100 == 0:
        return f"{sign}${absolute // 100}"
    return sign + f"${absolute / 100:.2f}"


def format_token_count(value: int | None) -> str:
    if value is None:
        return "—"
    scaled = float(max(value, 0))
    suffixes = ["", "K", "M", "B", "T"]
    index = 0
    while scaled >= 1000 and index < len(suffixes) - 1:
        scaled /= 1000
        index += 1
    if index < len(suffixes) - 1 and (round_half_away(scaled * 10) / 10) >= 1000:
        scaled /= 1000
        index += 1
    if index == 0:
        return str(round_half_away(scaled))
    tenths = round_half_away(scaled * 10)
    whole, frac = divmod(tenths, 10)
    if frac == 0:
        return f"{whole}{suffixes[index]}"
    return f"{whole}.{frac}{suffixes[index]}"


def membership_label(raw: str | None) -> str | None:
    if raw is None:
        return None
    key = raw.lower()
    if key in ("pro_plus", "pro-plus", "plus"):
        return "Pro+"
    if key == "pro":
        return "Pro"
    if key == "ultra":
        return "Ultra"
    if key in ("enterprise", "business", "team"):
        return "Team"
    if key in ("free", "hobby"):
        return "Free"
    return raw.replace("_", " ").title()


def window_start(days_ago: int, now: datetime) -> datetime:
    """Local start of the day `days_ago` days before now.

    A 7-day window uses days_ago=6 so today is included, matching the dashboard.
    """
    if now.tzinfo is None:
        local = now.replace(tzinfo=datetime.now().astimezone().tzinfo)
    else:
        local = now.astimezone(now.tzinfo)
    start_today = local.replace(hour=0, minute=0, second=0, microsecond=0)
    return start_today - timedelta(days=days_ago)


def epoch_millis(moment: datetime) -> int:
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    return int(moment.timestamp() * 1000)
