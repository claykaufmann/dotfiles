#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "trino>=0.330",
#   "keyring>=25.0",
#   "keyrings.alt>=5.0",
# ]
# ///
"""
Query the beta.team Trino cluster and emit results as CSV/JSON/TSV.

Defaults baked in for the host/user; override via flags only when needed.
OAuth2 tokens are cached in the macOS Keychain via the `keyring` package, so
the browser flow only triggers on first use (or after token expiry).

Usage:
    trino_query.py "SELECT 1"
    trino_query.py --catalog glue --schema aircraft_telemetry "SELECT * FROM standard LIMIT 5"
    cat query.sql | trino_query.py
    trino_query.py --format json --output /tmp/out.json "SELECT ..."
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from typing import Iterator, Sequence, TextIO

# --- Configure keyring BEFORE importing trino.auth ---
#
# The Trino client picks up `keyring` at import time and will crash if writes
# fail (e.g. inside pi's sandbox where macOS Keychain access is denied).
#
# We *unconditionally* route to a plaintext file under ~/.cache/pi (writable
# from any pi project, sandboxed or not). This keeps the cache deterministic
# across sandbox-on / sandbox-off sessions — Keychain isn't writable when
# sandboxed, and probing for it would silently invalidate the cache the next
# time the sandbox is toggled. The file is mode 0600, in the user's home, so
# this is no less secure than ~/.aws/credentials.
import keyring  # noqa: E402
import keyrings.alt.file  # noqa: E402


def _configure_keyring() -> str:
    cache_dir = os.path.expanduser("~/.cache/pi/trino-keyring")
    os.makedirs(cache_dir, mode=0o700, exist_ok=True)
    kr = keyrings.alt.file.PlaintextKeyring()
    kr.file_path = os.path.join(cache_dir, "keyring_pass.cfg")  # type: ignore[attr-defined]
    keyring.set_keyring(kr)
    return f"plaintext-file ({kr.file_path})"  # type: ignore[attr-defined]


_KEYRING_BACKEND = _configure_keyring()

from trino.auth import OAuth2Authentication, RedirectHandler  # noqa: E402
from trino.auth import _OAuth2TokenBearer  # noqa: E402
from trino.dbapi import connect  # noqa: E402

# Trino's default OAuth poll cap (5 attempts, server-driven delay ~1-2s each)
# gives the user only ~10s to complete browser auth before raising. When the
# browser is launched automatically that's fine, but in `--no-browser` mode
# the user has to copy-paste the URL and may take a minute. Bump unconditionally;
# it has no cost in the happy path.
_OAuth2TokenBearer.MAX_OAUTH_ATTEMPTS = 200  # type: ignore[attr-defined]


class PrintOnlyRedirectHandler(RedirectHandler):
    """Redirect handler that prints the auth URL prominently to stderr.

    Used when the default `CompositeRedirectHandler` can't launch a browser
    (e.g. inside pi's sandbox where `osascript`/`open` are blocked). The user
    copy-pastes the URL into a browser themselves; the script keeps polling
    for the token in the background.
    """

    def __call__(self, url: str) -> None:
        msg = (
            "\n"
            "================ TRINO OAUTH AUTH REQUIRED ================\n"
            f"{url}\n"
            "Open the URL above in a browser to complete authentication.\n"
            f"Token cache: {_KEYRING_BACKEND}\n"
            "This process will resume automatically once the token issues.\n"
            "===========================================================\n"
        )
        sys.stderr.write(msg)
        sys.stderr.flush()

DEFAULT_HOST = "trino.data.beta.team"
DEFAULT_USER = "ckaufmann@beta.team"
DEFAULT_HTTP_SCHEME = "https"


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Run a SQL query against the beta.team Trino cluster.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "sql",
        nargs="?",
        help="SQL to execute. If omitted, reads from stdin.",
    )
    p.add_argument("--host", default=DEFAULT_HOST, help=f"Trino host (default: {DEFAULT_HOST}).")
    p.add_argument("--user", default=DEFAULT_USER, help=f"Trino user (default: {DEFAULT_USER}).")
    p.add_argument("--catalog", default=None, help="Default catalog for unqualified table names.")
    p.add_argument("--schema", default=None, help="Default schema. Requires --catalog.")
    p.add_argument(
        "--format",
        choices=("csv", "tsv", "json"),
        default="csv",
        help="Output format (default: csv with header row).",
    )
    p.add_argument(
        "--limit-rows",
        type=int,
        default=None,
        help="Client-side cap on rows emitted (does not affect the SQL).",
    )
    p.add_argument(
        "--output",
        default=None,
        help="Write to this file instead of stdout. Use for large result sets.",
    )
    p.add_argument(
        "--no-browser",
        action="store_true",
        help=(
            "Don't try to launch a browser for OAuth; just print the auth URL "
            "to stderr for manual copy-paste. Use inside sandboxes that block "
            "`osascript`/`open` (e.g. pi)."
        ),
    )
    p.add_argument(
        "--no-spool",
        action="store_true",
        help=(
            "Disable Trino's spooled result protocol. By default the server "
            "spools large results to an S3 bucket (e.g. "
            "`beta-dev-temp-files.s3.amazonaws.com`) and the client downloads "
            "them directly, which fails inside sandboxes that don't allowlist "
            "that bucket. With this flag results stream inline through the "
            "Trino host \u2014 slower for huge result sets, but works anywhere "
            "`*.beta.team` is reachable."
        ),
    )
    args = p.parse_args(argv)

    if args.schema and not args.catalog:
        p.error("--schema requires --catalog")

    return args


def read_sql(args: argparse.Namespace) -> str:
    if args.sql:
        sql = args.sql
    else:
        sql = sys.stdin.read()
    sql = sql.strip().rstrip(";").strip()
    if not sql:
        sys.exit("error: no SQL provided (pass as argument or via stdin)")
    return sql


def iter_rows(cursor, cap: int | None) -> Iterator[Sequence]:
    n = 0
    while True:
        row = cursor.fetchone()
        if row is None:
            return
        yield row
        n += 1
        if cap is not None and n >= cap:
            return


def emit_csv(out: TextIO, columns: list[str], rows: Iterator[Sequence], delimiter: str) -> None:
    w = csv.writer(out, delimiter=delimiter, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    w.writerow(columns)
    for row in rows:
        w.writerow(["" if v is None else v for v in row])


def emit_json(out: TextIO, columns: list[str], rows: Iterator[Sequence]) -> None:
    # JSON-Lines: one object per row. Keeps streaming behavior and avoids
    # buffering the entire result set in memory.
    for row in rows:
        out.write(json.dumps(dict(zip(columns, row)), default=str))
        out.write("\n")


def run(args: argparse.Namespace, out: TextIO) -> int:
    sql = read_sql(args)

    auth_kwargs: dict = {}
    if args.no_browser:
        auth_kwargs["redirect_auth_url_handler"] = PrintOnlyRedirectHandler()

    conn_kwargs: dict = {
        "host": args.host,
        "user": args.user,
        "auth": OAuth2Authentication(**auth_kwargs),
        "http_scheme": DEFAULT_HTTP_SCHEME,
    }
    if args.no_spool:
        # Passing encoding=None tells the client not to advertise any spooling
        # encoding via X-Trino-Encoding, so the server falls back to the inline
        # result protocol (rows arrive in the query-status JSON, no S3 hop).
        conn_kwargs["encoding"] = None
    if args.catalog:
        conn_kwargs["catalog"] = args.catalog
    if args.schema:
        conn_kwargs["schema"] = args.schema

    conn = connect(**conn_kwargs)
    try:
        cur = conn.cursor()
        cur.execute(sql)
        # description is populated after execute() once the first batch arrives.
        if cur.description is None:
            # Statement produced no result set (DDL, etc.). Emit nothing.
            return 0
        columns = [d[0] for d in cur.description]
        rows = iter_rows(cur, args.limit_rows)
        if args.format == "csv":
            emit_csv(out, columns, rows, delimiter=",")
        elif args.format == "tsv":
            emit_csv(out, columns, rows, delimiter="\t")
        elif args.format == "json":
            emit_json(out, columns, rows)
    finally:
        try:
            conn.close()
        except Exception:
            pass
    return 0


def main() -> int:
    args = parse_args(sys.argv[1:])
    if args.output:
        with open(args.output, "w", encoding="utf-8", newline="") as fh:
            return run(args, fh)
    return run(args, sys.stdout)


if __name__ == "__main__":
    sys.exit(main())
