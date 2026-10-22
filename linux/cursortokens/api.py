"""Cursor dashboard calls used by the macOS app."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from cursortokens.formatting import epoch_millis, window_start
from cursortokens.session import header_value

SUMMARY_URL = "https://cursor.com/api/usage-summary"
PROFILE_URL = "https://cursor.com/api/auth/me"
AGGREGATED_URL = "https://cursor.com/api/dashboard/get-aggregated-usage-events"
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
)


class Unauthorized(Exception):
    pass


class APIError(Exception):
    pass


@dataclass
class Summary:
    membership: str | None
    cursor_percent: float | None
    other_percent: float | None
    on_demand_enabled: bool | None
    on_demand_used_cents: int | None
    on_demand_limit_cents: int | None


def _flex_float(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None


def _present_float(obj: dict[str, Any], key: str) -> float | None:
    if key not in obj:
        return None
    if obj[key] is None:
        return 0.0
    parsed = _flex_float(obj[key])
    if parsed is None:
        raise APIError(f"bad number for {key}")
    return parsed


def _round_int(value: float) -> int:
    from cursortokens.formatting import round_half_away

    return round_half_away(value)


def _nullable_int(obj: dict[str, Any], key: str) -> int | None:
    if key not in obj or obj[key] is None:
        return None
    parsed = _flex_float(obj[key])
    if parsed is None:
        raise APIError(f"bad number for {key}")
    return _round_int(parsed)


def parse_summary(payload: dict[str, Any]) -> Summary:
    individual = payload.get("individualUsage") or {}
    plan = individual.get("plan") or {}
    on_demand = individual.get("onDemand")
    enabled = None
    used = None
    limit = None
    if isinstance(on_demand, dict):
        if isinstance(on_demand.get("enabled"), bool):
            enabled = on_demand["enabled"]
        used = _nullable_int(on_demand, "used")
        limit = _nullable_int(on_demand, "limit")
    return Summary(
        membership=payload.get("membershipType") if isinstance(payload.get("membershipType"), str) else None,
        cursor_percent=_present_float(plan, "autoPercentUsed"),
        other_percent=_present_float(plan, "apiPercentUsed"),
        on_demand_enabled=enabled,
        on_demand_used_cents=used,
        on_demand_limit_cents=limit,
    )


def _token_piece(obj: dict[str, Any], key: str) -> int | None:
    if key not in obj:
        return None
    if obj[key] is None:
        return 0
    parsed = _flex_float(obj[key])
    if parsed is None:
        raise APIError(f"bad token count for {key}")
    return _round_int(parsed)


def parse_total_tokens(payload: dict[str, Any]) -> int:
    keys = (
        "totalInputTokens",
        "totalOutputTokens",
        "totalCacheWriteTokens",
        "totalCacheReadTokens",
    )
    parts = [_token_piece(payload, key) for key in keys]
    if any(part is not None for part in parts):
        return sum(part or 0 for part in parts)
    total = 0
    for row in payload.get("aggregations") or []:
        if not isinstance(row, dict):
            continue
        for key in ("inputTokens", "outputTokens", "cacheWriteTokens", "cacheReadTokens"):
            total += _token_piece(row, key) or 0
    return total


def parse_email(payload: dict[str, Any]) -> str | None:
    email = payload.get("email")
    return email if isinstance(email, str) and email else None


class Client:
    def __init__(self, session_value: str, opener=None):
        self.session_value = session_value
        self._opener = opener or urlopen

    def fetch_summary(self) -> Summary:
        return parse_summary(self._send(SUMMARY_URL, "GET", None))

    def fetch_email(self) -> str | None:
        return parse_email(self._send(PROFILE_URL, "GET", None))

    def fetch_total_tokens(self, start: datetime, end: datetime) -> int:
        body = {
            "teamId": -1,
            "startDate": epoch_millis(start),
            "endDate": epoch_millis(end),
        }
        return parse_total_tokens(self._send(AGGREGATED_URL, "POST", body))

    def _send(self, url: str, method: str, body: dict[str, Any] | None) -> dict[str, Any]:
        data = None if body is None else json.dumps(body).encode("utf-8")
        request = Request(url, data=data, method=method)
        request.add_header("Cookie", header_value(self.session_value))
        request.add_header("Origin", "https://cursor.com")
        request.add_header("Referer", "https://cursor.com/dashboard?tab=usage")
        request.add_header("Accept", "application/json")
        request.add_header("Content-Type", "application/json")
        request.add_header("User-Agent", USER_AGENT)
        try:
            with self._opener(request, timeout=30) as response:
                status = getattr(response, "status", None) or response.getcode()
                raw = response.read()
        except HTTPError as error:
            if error.code in (401, 403):
                raise Unauthorized() from error
            raise APIError(f"HTTP {error.code}") from error
        except URLError as error:
            raise APIError(str(error.reason)) from error
        if status in (401, 403):
            raise Unauthorized()
        if status < 200 or status >= 300:
            raise APIError(f"HTTP {status}")
        try:
            payload = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise APIError("bad response") from error
        if not isinstance(payload, dict):
            raise APIError("bad response")
        return payload


def seven_day_start(now: datetime) -> datetime:
    return window_start(6, now)
