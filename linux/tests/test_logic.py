import base64
import json
import os
import sqlite3
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from io import BytesIO
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

from cursortokens.api import APIError, parse_summary, parse_total_tokens
from cursortokens.cli import main
from cursortokens.formatting import (
    bar_fraction,
    exceeds_warning,
    format_cents,
    format_percent,
    format_token_count,
    membership_label,
    window_start,
)
from cursortokens.local_cursor import LocalSessionError, load_local_session
from cursortokens.refresh import refresh
from cursortokens.session import header_value, jwt_subject, normalize_stored
from cursortokens.snapshot import on_demand_block


class FormattingTests(unittest.TestCase):
    def test_percent_rounding_matches_dashboard(self):
        self.assertEqual(format_percent(41.2075), "41%")
        self.assertEqual(format_percent(82.672727), "83%")
        self.assertEqual(format_percent(None), "—")

    def test_token_counts_use_dashboard_scale(self):
        self.assertEqual(format_token_count(30_284_186), "30.3M")
        self.assertEqual(format_token_count(909_200_000), "909.2M")
        self.assertEqual(format_token_count(1_279_903_814), "1.3B")
        self.assertEqual(format_token_count(999_999), "1M")
        self.assertEqual(format_token_count(12), "12")
        self.assertEqual(format_token_count(None), "—")

    def test_on_demand_cents_and_warning_threshold(self):
        self.assertEqual(format_cents(0), "$0")
        self.assertEqual(format_cents(5_000), "$50")
        self.assertEqual(format_cents(1_250), "$12.50")
        self.assertEqual(format_cents(None), "—")
        self.assertFalse(exceeds_warning(90))
        self.assertFalse(exceeds_warning(82.67))
        self.assertTrue(exceeds_warning(90.5))
        self.assertTrue(exceeds_warning(96))
        demand = on_demand_block(True, 0, 5_000)
        self.assertEqual(demand["usageText"], "$0")
        self.assertEqual(demand["limitText"], "$50")
        self.assertEqual(demand["pairText"], "$0/$50")
        self.assertIsNone(on_demand_block(None, None, None))
        unlimited = on_demand_block(True, 1_250, None)
        self.assertEqual(unlimited["limitText"], "No limit")
        self.assertEqual(unlimited["pairText"], "$12.50")
        self.assertFalse(unlimited["hasBar"])

    def test_bar_fraction_clamps(self):
        self.assertAlmostEqual(bar_fraction(50), 0.5)
        self.assertAlmostEqual(bar_fraction(140), 1)
        self.assertAlmostEqual(bar_fraction(None), 0)

    def test_seven_day_window_includes_today(self):
        now = datetime.fromtimestamp(1_761_148_800, tz=timezone.utc)
        start = window_start(6, now)
        today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        self.assertEqual((today - start).days, 6)

    def test_membership_labels(self):
        self.assertEqual(membership_label("pro_plus"), "Pro+")
        self.assertEqual(membership_label("pro"), "Pro")
        self.assertEqual(membership_label("ultra"), "Ultra")
        self.assertEqual(membership_label("enterprise"), "Team")


class SessionTests(unittest.TestCase):
    def test_cookie_encodes_subject_separator(self):
        header = header_value("google-oauth2|abc::aaa.bbb.ccc")
        self.assertTrue(header.startswith("WorkosCursorSessionToken="))
        self.assertIn("%7C", header)
        self.assertIn("%3A%3A", header)
        self.assertNotIn("::", header)

    def test_raw_jwt_gains_subject(self):
        payload = base64.urlsafe_b64encode(b'{"sub":"google-oauth2|abc"}').decode().rstrip("=")
        token = f"eyJhbGciOiJIUzI1NiJ9.{payload}.sig"
        stored = normalize_stored(token)
        self.assertTrue(stored.startswith("google-oauth2|abc::"))
        self.assertEqual(jwt_subject(token), "google-oauth2|abc")


class DecodingTests(unittest.TestCase):
    def test_summary_percents_and_on_demand(self):
        summary = parse_summary(
            {
                "membershipType": "pro_plus",
                "individualUsage": {
                    "plan": {"autoPercentUsed": 41.2075, "apiPercentUsed": 82.67},
                    "onDemand": {"enabled": True, "used": 0, "limit": 5000, "remaining": 5000},
                },
            }
        )
        self.assertEqual(summary.membership, "pro_plus")
        self.assertAlmostEqual(summary.cursor_percent, 41.2075)
        self.assertAlmostEqual(summary.other_percent, 82.67)
        self.assertEqual(summary.on_demand_used_cents, 0)
        self.assertEqual(summary.on_demand_limit_cents, 5000)

        unlimited = parse_summary(
            {"individualUsage": {"onDemand": {"enabled": True, "used": 1250, "limit": None}}}
        )
        self.assertEqual(unlimited.on_demand_used_cents, 1250)
        self.assertIsNone(unlimited.on_demand_limit_cents)

    def test_aggregated_tokens(self):
        self.assertEqual(
            parse_total_tokens(
                {
                    "totalInputTokens": "10",
                    "totalOutputTokens": 2,
                    "totalCacheReadTokens": "30",
                    "aggregations": [],
                }
            ),
            42,
        )
        self.assertEqual(
            parse_total_tokens(
                {"aggregations": [{"inputTokens": "4", "outputTokens": "1", "cacheReadTokens": "5"}]}
            ),
            10,
        )


class LocalCursorTests(unittest.TestCase):
    def test_reads_access_token(self):
        payload = base64.urlsafe_b64encode(b'{"sub":"google-oauth2|abc"}').decode().rstrip("=")
        token = f"header.{payload}.sig"
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "state.vscdb"
            connection = sqlite3.connect(database)
            connection.execute("CREATE TABLE ItemTable (key TEXT, value TEXT)")
            connection.execute(
                "INSERT INTO ItemTable (key, value) VALUES ('cursorAuth/accessToken', ?)",
                (token,),
            )
            connection.commit()
            connection.close()
            stored = load_local_session(database)
        self.assertEqual(stored, f"google-oauth2|abc::{token}")

    def test_missing_database(self):
        with self.assertRaises(LocalSessionError):
            load_local_session(Path("/tmp/cursor-tokens-missing-state.vscdb"))


class RefreshTests(unittest.TestCase):
    def test_refresh_writes_display_snapshot(self):
        class Response:
            status = 200

            def __init__(self, payload):
                self._payload = json.dumps(payload).encode()

            def read(self):
                return self._payload

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

        def opener(request, timeout=30):
            url = request.full_url
            if url.endswith("/usage-summary"):
                return Response(
                    {
                        "membershipType": "pro_plus",
                        "individualUsage": {
                            "plan": {"autoPercentUsed": 44.2, "apiPercentUsed": 96.2},
                            "onDemand": {"enabled": True, "used": 0, "limit": 5000},
                        },
                    }
                )
            if url.endswith("/auth/me"):
                return Response({"email": "person@example.com"})
            return Response({"totalInputTokens": 1200, "totalOutputTokens": 30})

        with tempfile.TemporaryDirectory() as directory:
            os.environ["CURSOR_TOKENS_DATA_DIR"] = directory
            try:
                from cursortokens.store import save_session

                save_session("google-oauth2|abc::token")
                snapshot = refresh(now=datetime(2026, 10, 22, 18, 0, tzinfo=timezone.utc), client_factory=lambda session: __import__("cursortokens.api", fromlist=["Client"]).Client(session, opener))
            finally:
                os.environ.pop("CURSOR_TOKENS_DATA_DIR", None)
        self.assertTrue(snapshot["signedIn"])
        self.assertEqual(snapshot["membership"], "Pro+")
        self.assertEqual(snapshot["cursor"]["text"], "44%")
        self.assertFalse(snapshot["cursor"]["warning"])
        self.assertEqual(snapshot["other"]["text"], "96%")
        self.assertTrue(snapshot["other"]["warning"])
        self.assertEqual(snapshot["onDemand"]["pairText"], "$0/$50")
        self.assertEqual(snapshot["tokens"]["today"], "1.2K")
        self.assertEqual(snapshot["email"], "person@example.com")

    def test_unauthorized_clears_session(self):
        def opener(request, timeout=30):
            raise HTTPError(request.full_url, 401, "unauthorized", hdrs=None, fp=BytesIO(b""))

        with tempfile.TemporaryDirectory() as directory:
            os.environ["CURSOR_TOKENS_DATA_DIR"] = directory
            try:
                from cursortokens.store import load_session, save_session

                save_session("google-oauth2|abc::token")
                from cursortokens.api import Client

                snapshot = refresh(client_factory=lambda session: Client(session, opener))
                self.assertFalse(snapshot["signedIn"])
                self.assertEqual(snapshot["error"], "Session expired. Sign in again.")
                self.assertIsNone(load_session())
            finally:
                os.environ.pop("CURSOR_TOKENS_DATA_DIR", None)

    def test_cli_show_without_session(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["CURSOR_TOKENS_DATA_DIR"] = directory
            try:
                with patch("sys.stdout") as stdout:
                    stdout.write = lambda text: collected.append(text)
                    collected = []
                    code = main(["show"])
                text = "".join(collected)
            finally:
                os.environ.pop("CURSOR_TOKENS_DATA_DIR", None)
        self.assertEqual(code, 0)
        self.assertFalse(json.loads(text)["signedIn"])


class PackageTests(unittest.TestCase):
    def test_plasmoid_metadata_is_plasma6(self):
        root = Path(__file__).resolve().parents[1] / "plasmoid"
        metadata = json.loads((root / "metadata.json").read_text())
        self.assertEqual(metadata["KPackageStructure"], "Plasma/Applet")
        self.assertEqual(metadata["X-Plasma-API-Minimum-Version"], "6.0")
        self.assertEqual(metadata["KPlugin"]["Id"], "org.tx.cursortokenwidget")
        main = (root / "contents" / "ui" / "main.qml").read_text()
        self.assertIn("PlasmoidItem", main)
        self.assertIn("activationTogglesExpanded: false", main)
        self.assertIn("org.kde.plasma.plasma5support", main)
        self.assertNotIn("org.kde.plasma.core 2.0", main)
        self.assertIn("@CURSOR_TOKENS_BIN@", main)
        config = (root / "contents" / "ui" / "configGeneral.qml").read_text()
        self.assertIn("sign-in", config)
        self.assertIn("--local", config)
        self.assertNotIn("WorkosCursorSessionToken=", config)


if __name__ == "__main__":
    unittest.main()
