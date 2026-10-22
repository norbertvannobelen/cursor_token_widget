"""XDG state for the session and the last snapshot."""

from __future__ import annotations

import json
import os
from pathlib import Path


def data_dir() -> Path:
    override = os.environ.get("CURSOR_TOKENS_DATA_DIR")
    if override:
        path = Path(override)
    else:
        base = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
        path = Path(base) / "cursor-tokens"
    path.mkdir(parents=True, exist_ok=True)
    return path


def session_path() -> Path:
    return data_dir() / "session"


def snapshot_path() -> Path:
    return data_dir() / "snapshot.json"


def _write_private(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(text, encoding="utf-8")
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)
    os.chmod(path, 0o600)


def load_session() -> str | None:
    path = session_path()
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8").strip()
    return text or None


def save_session(value: str) -> None:
    _write_private(session_path(), value.strip() + "\n")


def delete_session() -> None:
    try:
        session_path().unlink()
    except FileNotFoundError:
        return


def load_snapshot() -> dict | None:
    path = snapshot_path()
    if not path.exists():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def save_snapshot(snapshot: dict) -> None:
    _write_private(snapshot_path(), json.dumps(snapshot, indent=2, sort_keys=True) + "\n")
