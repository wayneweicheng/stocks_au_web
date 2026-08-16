# Trading Signal Report Catalog Operations

The canonical report browser is `/trading-signal-reports`, backed by the read-only `/api/trading-signal-reports` catalog and immutable `/{public_report_id}.html` endpoint. It reads `StockDB_US.TradingSignal.ReportSnapshot`; it does not import strategy implementations, connect to IB, calculate signals, write runtime state, or publish notifications.

Legacy `/spx-gex-reports` and `/api/spx-gex/...` paths are compatibility aliases. The page redirects to the generic catalog with a SPX filter, and the API aliases resolve ReportSnapshot/FileName/ReportAlias data only. The old live-quote endpoint returns `410 Gone`.

HTML access uses either the configured report token or existing authenticated access. Token comparison is constant-time. Responses include ETag, immutable cache headers, CSP, `nosniff`, and `no-referrer`; the frontend uses a sandboxed iframe and never injects report HTML through `srcDoc`.

Pushover notification URLs open `/trading-signal-reports?public_report_id=...`. The page preserves this deep-link ID while the user signs in, then fetches the immutable HTML with the authenticated application request before displaying it. Notification URLs must not contain the shared report token.

Operational checks:

```powershell
Set-Location C:\Repo\stocks_au_web\backend
..\venv\Scripts\python.exe -m unittest tests.test_trading_signal_reports

Set-Location C:\Repo\stocks_au_web\frontend
npm run lint
npm run build
```

The report token is supplied outside Git and must not appear in HTML, API catalog payloads, logs, screenshots, task arguments, or evidence. Rotate it by updating the secret store and runtime/web configuration together, then verify one operator-only immutable link.
