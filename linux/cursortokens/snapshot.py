"""Snapshot JSON consumed by the Plasma widget and the Kirigami window."""

from __future__ import annotations

from datetime import datetime

from cursortokens.formatting import (
    bar_fraction,
    exceeds_warning,
    format_cents,
    format_percent,
    format_token_count,
    membership_label,
    percent_of_limit,
)


def _meter(percent: float | None) -> dict:
    return {
        "text": format_percent(percent),
        "fraction": bar_fraction(percent),
        "warning": exceeds_warning(percent),
    }


def on_demand_block(
    enabled: bool | None,
    used_cents: int | None,
    limit_cents: int | None,
) -> dict | None:
    if enabled is None and used_cents is None and limit_cents is None:
        return None
    usage_text = format_cents(used_cents or 0)
    if limit_cents is not None:
        limit_text = format_cents(limit_cents)
        pair_text = f"{usage_text}/{limit_text}"
    elif enabled is False:
        limit_text = "Off"
        pair_text = usage_text
    else:
        limit_text = "No limit"
        pair_text = usage_text
    percent = percent_of_limit(used_cents, limit_cents)
    return {
        "usageText": usage_text,
        "limitText": limit_text,
        "pairText": pair_text,
        "fraction": bar_fraction(percent) if percent is not None else 0.0,
        "hasBar": percent is not None,
        "warning": exceeds_warning(percent),
    }


def _clock(moment: datetime) -> str:
    local = moment.astimezone()
    hour = local.strftime("%I").lstrip("0") or "0"
    return f"{hour}:{local.strftime('%M %p')}"


def make_snapshot(
    *,
    signed_in: bool,
    cursor_percent: float | None = None,
    other_percent: float | None = None,
    today_tokens: int | None = None,
    week_tokens: int | None = None,
    month_tokens: int | None = None,
    on_demand_enabled: bool | None = None,
    on_demand_used_cents: int | None = None,
    on_demand_limit_cents: int | None = None,
    membership: str | None = None,
    email: str | None = None,
    updated_at: datetime | None = None,
    error: str | None = None,
) -> dict:
    updated = updated_at or datetime.now().astimezone()
    return {
        "signedIn": signed_in,
        "email": email or "",
        "membership": membership_label(membership) or "",
        "cursor": _meter(cursor_percent),
        "other": _meter(other_percent),
        "onDemand": on_demand_block(on_demand_enabled, on_demand_used_cents, on_demand_limit_cents),
        "tokens": {
            "today": format_token_count(today_tokens),
            "week": format_token_count(week_tokens),
            "month": format_token_count(month_tokens),
        },
        "updatedAt": updated.astimezone().isoformat(),
        "updatedText": _clock(updated),
        "error": error,
    }


def signed_out(error: str | None = None, updated_at: datetime | None = None) -> dict:
    return make_snapshot(signed_in=False, updated_at=updated_at, error=error)
