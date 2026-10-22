"""Cursor session cookie handling. The stored form is subject::jwt."""

from __future__ import annotations

import base64
import json
from urllib.parse import quote, unquote


def _decode_fully(value: str) -> str:
    current = value
    for _ in range(2):
        decoded = unquote(current)
        if decoded == current:
            break
        current = decoded
    return current


def jwt_subject(token: str) -> str:
    parts = token.split(".")
    if len(parts) < 2:
        raise ValueError("malformed token")
    payload = parts[1].replace("-", "+").replace("_", "/")
    payload += "=" * ((-len(payload)) % 4)
    try:
        data = json.loads(base64.b64decode(payload))
    except (ValueError, json.JSONDecodeError) as error:
        raise ValueError("malformed token") from error
    subject = data.get("sub") if isinstance(data, dict) else None
    if not isinstance(subject, str) or not subject:
        raise ValueError("missing subject")
    return subject


def normalize_stored(value: str) -> str:
    trimmed = value.strip()
    prefix = "WorkosCursorSessionToken="
    if trimmed.startswith(prefix):
        trimmed = trimmed[len(prefix) :]
    decoded = _decode_fully(trimmed)
    if "::" in decoded:
        return decoded
    try:
        subject = jwt_subject(decoded)
    except ValueError:
        return decoded
    return f"{subject}::{decoded}"


def header_value(stored: str) -> str:
    encoded = quote(normalize_stored(stored), safe="-._~")
    return f"WorkosCursorSessionToken={encoded}"
