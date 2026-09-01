---
name: trino-query
description: Run SQL queries against the beta.team Trino cluster (https://trino.data.beta.team) and return results as CSV. Use whenever the user asks to query Trino, run a Trino query, query the data lake/warehouse via Trino, look up data in glue/iceberg/hive catalogs, or anything of the form "use trino to ...". The OAuth token is cached in macOS Keychain after the first browser auth, so subsequent queries are non-interactive.
---

# trino-query

Runs SQL against `https://trino.data.beta.team` as `ckaufmann@beta.team` using the Trino Python client with OAuth2. Results are returned as CSV with a header row on stdout.

## How to invoke

Always run the bundled script via `uv run` (PEP 723 inline metadata pins `trino` + `keyring`, so no setup is required):

```bash
uv run /Users/ckaufmann/.pi/agent/skills/trino-query/scripts/trino_query.py "SELECT * FROM glue.aircraft_telemetry.standard LIMIT 10"
```

Read the SQL from stdin (preferred for multi-line queries — avoids shell quoting hell):

```bash
uv run /Users/ckaufmann/.pi/agent/skills/trino-query/scripts/trino_query.py <<'SQL'
SELECT col_a, col_b
FROM glue.aircraft_telemetry.standard
WHERE event_time > current_timestamp - interval '1' day
LIMIT 100
SQL
```

Optional flags:

| Flag | Default | Purpose |
|---|---|---|
| `--catalog <name>` | _(none)_ | Sets default catalog so SQL can use unqualified names. |
| `--schema <name>` | _(none)_ | Sets default schema. Requires `--catalog`. |
| `--format csv\|json\|tsv` | `csv` | Output format. CSV includes a header row. |
| `--limit-rows N` | _(none)_ | Hard cap on rows returned by the script (applied client-side). |
| `--output <path>` | _(stdout)_ | Write to a file instead of stdout. Use this when the result set is large enough that bash output truncation would clip it. |
| `--no-browser` | off | Skip browser launch on OAuth. Prints the auth URL to stderr for manual copy-paste. **Pass this whenever running from inside pi**, since the sandbox blocks `osascript`/`open` and the default handler errors out before the URL is visible. |
| `--no-spool` | off | Disable Trino's spooled result protocol so rows stream inline through the Trino host instead of being downloaded from `beta[-dev]-temp-files.s3.amazonaws.com`. **Pass this whenever those S3 hosts aren't in the sandbox allowlist.** Slower for huge result sets but otherwise transparent. |
| `--host <fqdn>` | `trino.data.beta.team` | Override the Trino host. Use `trino.dev.data.beta.team` for the dev cluster. Each host gets its own keychain token cache entry. |

## Running inside pi's sandbox

Pi's network sandbox proxies all egress through `localhost:65526` and only allows the hosts listed in `~/.pi/agent/sandbox.json` (`network.allowedDomains`). The Trino servers themselves are covered by the standard `*.beta.team` entry, but two other surfaces matter:

1. **OAuth browser launch** — the default `CompositeRedirectHandler` calls `osascript`/`open` to launch Chrome, which the sandbox blocks. Always pass **`--no-browser`** when invoking from inside pi; the auth URL is printed to stderr for copy-paste. The OAuth poll cap is bumped to 200 attempts so you have several minutes to complete the flow.

2. **Spooled results land in S3** — by default Trino writes large query results to an S3 bucket and the client downloads them directly. The buckets are not on `*.beta.team` and so are blocked. Two ways to deal with this, in order of preference:

   - **Pass `--no-spool`.** Disables the spooling protocol entirely so rows arrive inline through the Trino host. Works without any sandbox edits. Slower for huge result sets (the Trino coordinator paginates the JSON response itself).
   - **Allowlist the buckets.** Add to `network.allowedDomains` in `~/.pi/agent/sandbox.json`:

     ```json
     "beta-dev-temp-files.s3.amazonaws.com",
     "beta-temp-files.s3.amazonaws.com"
     ```

     The first is the dev-cluster bucket, the second is the inferred prod-cluster bucket (same `beta[-dev]-temp-files` naming convention). With these allowlisted, drop `--no-spool` and queries use the faster spooled protocol.

3. **Token cache location** — the script always stores its OAuth token at `~/.cache/pi/trino-keyring/keyring_pass.cfg` (mode 0600). It does **not** use macOS Keychain; Keychain writes silently fail under pi's sandbox, and the file path is sandbox-stable so a token cached during a sandbox-on session is reused when the sandbox is off (and vice versa).

## OAuth flow (read this once)

1. **First query of the day (or after token expiry)**: the script prints the auth URL. With the default handler it also asks macOS to open Chrome via `osascript`/`open`; with `--no-browser` it only prints the URL to stderr for copy-paste. The bash call blocks while the script polls (up to ~200 attempts) for the token. The token is then stored at `~/.cache/pi/trino-keyring/keyring_pass.cfg` keyed by host (e.g. `trino.dev.data.beta.team@ckaufmann@beta.team`).
2. **Subsequent queries**: the file cache is consulted, no browser opens, the query runs immediately. The cache is shared across pi sandbox-on / sandbox-off sessions because `~/.cache/pi` is writable in both.
3. **If a query hangs > 30 s and you didn't pass `--no-browser`**: the user probably hasn't seen the auth URL because the browser launch silently failed (sandbox, no GUI, etc.). Re-run with `--no-browser` so the URL is plainly visible in stderr.

## Defaults baked into the script

- Host: `trino.data.beta.team` (override with `--host trino.dev.data.beta.team` for dev)
- HTTP scheme: `https`
- User: `ckaufmann@beta.team`
- Auth: `OAuth2Authentication`. Default redirect handler opens the browser; `--no-browser` swaps in a print-only handler.
- Result protocol: spooled (fast for large results, requires S3 bucket reachability). `--no-spool` falls back to inline.
- Token cache: plaintext file at `~/.cache/pi/trino-keyring/keyring_pass.cfg`, mode 0600. Chosen unconditionally over macOS Keychain so behavior is identical inside and outside pi's sandbox.
- OAuth poll cap: 200 attempts (raised from the upstream default of 5) so manual `--no-browser` auth has a multi-minute window.

## When to use the CLI instead

The bundled `trino` CLI (`/opt/homebrew/bin/trino`) is also available and may be better when:

- The user wants to keep an interactive REPL open across many ad-hoc queries.
- A query is expected to be very large and they want streaming pager output.
- The Python script fails for an environmental reason and the CLI's error message is more diagnostic.

CLI invocation pattern (note: the CLI does **not** persist the OAuth token across invocations, so it re-prompts every run — prefer the Python script for repeated agent-driven queries):

```bash
trino --server https://trino.data.beta.team \
      --external-authentication \
      --user ckaufmann@beta.team \
      --output-format CSV_HEADER \
      --execute "SELECT 1"
```

## Composing queries

- Always write fully-qualified names (`<catalog>.<schema>.<table>`) unless you've passed `--catalog`/`--schema`. Trino has many catalogs registered.
- Discover schemas/tables with `SHOW CATALOGS`, `SHOW SCHEMAS FROM <catalog>`, `SHOW TABLES FROM <catalog>.<schema>`, `DESCRIBE <catalog>.<schema>.<table>`.
- Always include a `LIMIT` on exploratory queries — the cluster is shared and result sets can be huge.

## Result handling

- The script prints CSV to stdout. Use the agent's `read`/parsing primitives to inspect it.
- If a result might exceed pi's bash output truncation (~50 KB), pass `--output /tmp/trino-result.csv` and read the file back in chunks instead.
