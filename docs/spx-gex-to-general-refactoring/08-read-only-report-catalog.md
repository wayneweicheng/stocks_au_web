# Task 08: Build the Read-Only FastAPI Report Catalog

## Objective

Replace the SPX-specific report-serving seam with a generic, read-only FastAPI `ReportCatalog` backed by `StockDB_US.[TradingSignal]`. The web application must not calculate signals, access IB, process lifecycle state, publish notifications, or import `strategy_runtime`.

## Prerequisites

- Tasks 04 and 06 are complete.
- Task 02 report views and stored procedures have stable output contracts.
- Representative SPX Report Snapshots exist in an integration database.

## Repository and file areas

Repository: `C:\Repo\stocks_au_web`

Create or update:

```text
backend\app\repositories\trading_signal_reports.py
backend\app\routers\trading_signal_reports.py
backend\app\schemas\trading_signal_reports.py
backend\app\core\config.py
backend\app\main.py
backend\tests\test_trading_signal_reports.py
backend\tests\test_spx_gex_strategy.py
```

The precise repository folder may follow existing backend conventions. Keep SQL access behind one catalog class or function group, not inside route handlers.

## Database access boundary

- Use a dedicated SQL Server connection setting for `StockDB_US` report reads.
- Prefer a database principal granted `SELECT` on `v_ReportCatalog` and `v_ReportSnapshotContent`, or `EXECUTE` only on the Task 02 read procedures.
- The web principal must have no insert/update/delete/execute rights over runtime write procedures or `StockDB.Notification`.
- Use bound parameters for all filters and identifiers.
- Configure connect/query timeouts and close connections deterministically.
- Do not expose raw SQL errors, server names, connection strings, HTML internals, or row IDs to clients.

## HTTP API

Implement:

```text
GET /api/trading-signal-reports
GET /api/trading-signal-reports/latest
GET /api/trading-signal-reports/{public_report_id}.html
```

### Catalog list

Support bounded, server-side filtering:

- `date_from` and `date_to` by report market date;
- `strategy_code`;
- `instrument_code`;
- `environment`;
- `report_kind`;
- case-insensitive free-text `search` over explicitly allowed display fields;
- `limit` with a conservative default and hard maximum;
- opaque continuation `cursor`.

Order deterministically by market/report date descending, generated UTC descending, then public ID. Do not use offset pagination. Return metadata only, never `HtmlContent`.

The opaque cursor must encode/version the final ordering tuple plus a hash of normalized filters. Reject malformed/tampered cursors and cursors reused with different filters; do not interpolate cursor content into SQL.

The response must include public report ID, strategy/version/deployment display metadata, subject/execution Instrument metadata where applicable, Environment, report kind, market/report dates, revision, generated UTC, superseded/current indicator, title/summary, and HTML URL.

### Latest

Require enough filters to avoid an ambiguous global `latest`. At minimum require `strategy_code`; support Instrument, Environment, and report kind. Return `404` when no matching report exists. Exclude superseded reports by default, with no client flag to accidentally choose an old revision.

### Immutable HTML

- Look up by opaque `public_report_id`, never database identity or filename.
- Return the stored HTML bytes/text unchanged with `Content-Type: text/html; charset=utf-8`.
- Set a restrictive Content Security Policy, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, and a cache policy appropriate to immutable content.
- Return `ETag` from the stored content hash and honor `If-None-Match`.
- Return `404` for unknown IDs; do not reveal whether an ID was malformed versus absent.
- Do not rewrite links, inject live data, or resolve a newer revision.

## Authentication and report tokens

Keep the existing authenticated website controls for catalog/list access. The immutable HTML endpoint must also support the Task 05 notification-link token when configured:

- accept the token only through the agreed `report_token` query parameter;
- compare using a constant-time comparison;
- allow either a valid authenticated session or valid token;
- never write the token to INFO logs or an error response;
- configure application and reverse-proxy/access logging to redact the `report_token` query value;
- reject missing/invalid credentials consistently;
- document that the shared token grants read access to any report URL whose opaque ID is known.

If the existing site already has a safer signed-link mechanism, implement an equivalent expiring/signature design only after updating Task 05 and recording the contract change. Do not invent mismatched URL behavior in this task.

## Legacy SPX compatibility

Keep `/spx-gex-reports` browser navigation working in Task 09. For existing SPX API/report URLs:

- `/api/spx-gex/reports` returns the old response shape from generic catalog metadata and is deprecated;
- `/api/spx-gex/report.html` performs a generic latest-SPX lookup and issues a non-permanent redirect to that immutable public-ID URL; it is a mutable latest alias and must not be used in new notifications;
- `/api/spx-gex/reports/{spx-gex-report-...html}` resolves the Task 10 filename alias and may permanently redirect to the exact immutable snapshot;
- `/api/spx-gex/reports/{date}.html?report_id={legacy-id}` resolves the exact imported identity/alias and may permanently redirect;
- `/api/spx-gex/reports/{date}.html` without `report_id` keeps the historical date-latest behavior through a non-permanent/no-cache redirect to the current non-superseded SPX report for that date;
- mark SPX-specific API routes deprecated in OpenAPI;
- do not call the legacy SPX storage/service merely to preserve a URL.

`/api/spx-gex/live-nq` is not part of `ReportCatalog`. Keep it unchanged only until Task 12; at cutover remove it or return `410 Gone` with a documented replacement if one exists. Never hide IB access or runtime execution in the catalog.

## Failure behavior

- Database timeout/unavailability returns a generic `503` with a correlation ID.
- Invalid filters return `422`.
- Oversized limits are rejected or clamped consistently and tested.
- One request performs a bounded number of SQL calls and does not read full HTML during listing.
- Log timing, result count, and correlation ID without query secrets or report tokens.

## Tests

Use repository fakes for most route tests and separately marked SQL integration tests. Cover:

- each filter alone and in combination;
- invalid date ranges and a cursor reused with different filters;
- stable cursor pagination with equal timestamps;
- no HTML in list responses;
- latest excludes superseded revisions;
- exact immutable HTML, ETag, and `304` behavior;
- authenticated and token-authorized reads;
- invalid/missing token with redacted logs;
- SQL injection-shaped filter input remains data;
- unknown public ID;
- database timeout/error sanitization;
- legacy SPX alias resolution;
- import guard proving router/repository modules do not import `strategy_runtime`, IB, or legacy execution/service modules.

## Acceptance criteria

- FastAPI serves generic report metadata and immutable HTML from SQL Server.
- The implementation is read-only by database permission and code path.
- The endpoints contain no SPX classification assumptions.
- A report link emitted by Task 05 opens successfully with the configured token.
- Existing stored SPX links have an explicit compatibility path.
- Backend startup does not construct the new runtime.

## Out of scope

- Frontend redesign.
- Triggering evaluations/reruns from HTTP.
- Enabling scheduler cutover.
- Deleting legacy SPX modules.
- Editing report HTML after storage.

## Verification

```powershell
Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_trading_signal_reports
..\venv\Scripts\python.exe -m unittest tests.test_spx_gex_strategy

Set-Location C:\Repo\stocks_au_web
rg -n "strategy_runtime|ib_insync|spx_gex_strategy.service|spx_gex_strategy.jobs" backend\app\repositories\trading_signal_reports.py backend\app\routers\trading_signal_reports.py
git diff --check
```

The `rg` command should produce no prohibited runtime imports. A harmless string in a deprecation message must be explained.

## Required handoff evidence

- API request/response examples with secrets removed.
- Database grants used by the web principal.
- Query plan or timing evidence for a representative catalog page.
- Successful tokenized report-link test.
- Legacy URL compatibility matrix.
- Import-boundary check and backend test output.
