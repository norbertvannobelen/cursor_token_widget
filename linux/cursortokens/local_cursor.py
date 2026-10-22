"""Read the account already signed in to the Cursor editor."""

from __future__ import annotations

import os
import sqlite3
from pathlib import Path

from cursortokens.session import jwt_subject


class LocalSessionError(Exception):
    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


def cursor_database_path() -> Path:
    config = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(config) / "Cursor" / "User" / "globalStorage" / "state.vscdb"


def load_local_session(database: Path | None = None) -> str:
    path = database or cursor_database_path()
    if not path.exists():
        raise LocalSessionError("Cursor doesn't look installed for this user.")
    uri = f"{path.resolve().as_uri()}?mode=ro"
    try:
        connection = sqlite3.connect(uri, uri=True, timeout=2)
    except sqlite3.Error as error:
        raise LocalSessionError("Couldn't read the Cursor session. Paste a session token instead.") from error
    try:
        row = connection.execute(
            "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1"
        ).fetchone()
    except sqlite3.Error as error:
        raise LocalSessionError("Couldn't read the Cursor session. Paste a session token instead.") from error
    finally:
        connection.close()
    if not row or not isinstance(row[0], str) or not row[0].strip():
        raise LocalSessionError("Cursor is installed, but no account is signed in.")
    token = row[0].strip()
    try:
        subject = jwt_subject(token)
    except ValueError as error:
        raise LocalSessionError(
            "The Cursor session on this computer couldn't be used. Paste a session token instead."
        ) from error
    return f"{subject}::{token}"
