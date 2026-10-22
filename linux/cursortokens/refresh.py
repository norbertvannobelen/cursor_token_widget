"""Fetch the dashboard and write the shared snapshot."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

from cursortokens.api import APIError, Client, Unauthorized
from cursortokens.formatting import window_start
from cursortokens.snapshot import make_snapshot, signed_out
from cursortokens.store import delete_session, load_session, load_snapshot, save_snapshot


def _previous_signed_in() -> dict | None:
    previous = load_snapshot()
    if previous and previous.get("signedIn") is True:
        return previous
    return None


def refresh(now: datetime | None = None, client_factory=Client) -> dict:
    moment = now or datetime.now().astimezone()
    session = load_session()
    if not session:
        snapshot = signed_out(updated_at=moment)
        save_snapshot(snapshot)
        return snapshot

    client = client_factory(session)
    previous = _previous_signed_in()
    try:
        summary = client.fetch_summary()
    except Unauthorized:
        delete_session()
        snapshot = signed_out(error="Session expired. Sign in again.", updated_at=moment)
        save_snapshot(snapshot)
        return snapshot
    except APIError:
        snapshot = previous or signed_out(updated_at=moment)
        snapshot = dict(snapshot)
        snapshot["error"] = "Couldn't reach Cursor. Showing the last update."
        save_snapshot(snapshot)
        return snapshot

    today_start = window_start(0, moment)
    week_start = window_start(6, moment)
    month_start = window_start(29, moment)

    def tokens(start: datetime) -> int | None:
        try:
            return client.fetch_total_tokens(start, moment)
        except (APIError, Unauthorized):
            return None

    def email() -> str | None:
        try:
            return client.fetch_email()
        except (APIError, Unauthorized):
            return None

    with ThreadPoolExecutor(max_workers=4) as pool:
        today_job = pool.submit(tokens, today_start)
        week_job = pool.submit(tokens, week_start)
        month_job = pool.submit(tokens, month_start)
        email_job = pool.submit(email)
        today_tokens = today_job.result()
        week_tokens = week_job.result()
        month_tokens = month_job.result()
        address = email_job.result()

    snapshot = make_snapshot(
        signed_in=True,
        cursor_percent=summary.cursor_percent,
        other_percent=summary.other_percent,
        today_tokens=today_tokens,
        week_tokens=week_tokens,
        month_tokens=month_tokens,
        on_demand_enabled=summary.on_demand_enabled,
        on_demand_used_cents=summary.on_demand_used_cents,
        on_demand_limit_cents=summary.on_demand_limit_cents,
        membership=summary.membership,
        email=address,
        updated_at=moment,
        error=None,
    )
    save_snapshot(snapshot)
    return snapshot
