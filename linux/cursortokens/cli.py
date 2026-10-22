"""Command line used by the Plasma widget and the Kirigami window."""

from __future__ import annotations

import argparse
import base64
import json
import sys

from cursortokens.local_cursor import LocalSessionError, load_local_session
from cursortokens.refresh import refresh
from cursortokens.session import normalize_stored
from cursortokens.snapshot import signed_out
from cursortokens.store import delete_session, load_snapshot, save_session, save_snapshot


def _emit(snapshot: dict) -> int:
    json.dump(snapshot, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def _sign_in(stored: str) -> int:
    normalized = normalize_stored(stored)
    if "::" not in normalized:
        snapshot = signed_out(error="That session token could not be used.")
        save_snapshot(snapshot)
        return _emit(snapshot)
    save_session(normalized)
    return _emit(refresh())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="cursor-tokens")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("show", help="Print the last snapshot")
    sub.add_parser("refresh", help="Fetch Cursor and print the snapshot")
    sub.add_parser("sign-out", help="Forget the session")

    sign_in = sub.add_parser("sign-in", help="Store a session and refresh")
    sign_in.add_argument("--local", action="store_true", help="Use the Cursor editor session")
    sign_in.add_argument("--token-base64", help="Base64-encoded session cookie or jwt")

    args = parser.parse_args(argv)
    if args.command == "show":
        return _emit(load_snapshot() or signed_out())
    if args.command == "refresh":
        return _emit(refresh())
    if args.command == "sign-out":
        delete_session()
        snapshot = signed_out()
        save_snapshot(snapshot)
        return _emit(snapshot)
    if args.command == "sign-in":
        if args.local:
            try:
                stored = load_local_session()
            except LocalSessionError as error:
                snapshot = signed_out(error=error.message)
                save_snapshot(snapshot)
                return _emit(snapshot)
            return _sign_in(stored)
        if args.token_base64:
            try:
                raw = base64.b64decode(args.token_base64, validate=True).decode("utf-8")
            except (ValueError, UnicodeDecodeError):
                snapshot = signed_out(error="That session token could not be used.")
                save_snapshot(snapshot)
                return _emit(snapshot)
            return _sign_in(raw)
        snapshot = signed_out(error="Choose the Cursor account on this computer, or paste a session token.")
        save_snapshot(snapshot)
        return _emit(snapshot)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
