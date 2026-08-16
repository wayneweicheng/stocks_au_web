# Agent instructions

## Web site changes

When web site changes are made in this project, do not start or restart the web app for testing. Complete the relevant static checks or build checks, then let the user know the changes are ready so they can restart the web app and test them.

## SQL Server and ODBC connection diagnostics

The production trading-signal data is SQL Server-backed. When a live probe is
needed, use the database settings already present in
`C:\Repo\stocks_au_web\backend\.env`; do not create a second set of
credentials or print secrets.

### Known Windows failure and the fix

In the restricted/sandboxed shell, the ODBC client can fail before a query is
executed with errors such as:

- `Encryption not supported on the client`
- `SSL Provider: No credentials are available in the security package`
- `08001` or `SEC_E_NO_CREDENTIALS (0x8009030E)`

These errors are an environment/Windows Schannel credential-acquisition
failure. They do not prove that SQL Server, the schema, or the query is wrong.
`Test-NetConnection <server> -Port 1433` only proves that the TCP port is
reachable; it does not prove that the TLS handshake works.

The proven procedure is:

1. Keep the probe read-only and verify the TCP port if useful.
2. Run the probe in an elevated/out-of-sandbox PowerShell invocation. In the
   tool call this means `sandbox_permissions: "require_escalated"` with a
   short justification, not repeated attempts from the restricted shell.
3. Use the collecting repository's Python environment and ODBC Driver 18:
   `C:\Repo\stocks_collecting\.venv\Scripts\python.exe`.
4. Use SQL authentication from `backend\.env`, `DATABASE=StockDB`, and the
   existing cross-database object names such as `[StockDB_US].[TradingSignal]`.
5. Use encrypted SQL authentication with the current server certificate
   handling: `Encrypt=yes;TrustServerCertificate=yes;`. If a valid server CA
   certificate is installed later, prefer certificate validation instead of
   trusting the server certificate.

The connection-string shape is:

```text
DRIVER={ODBC Driver 18 for SQL Server};
SERVER=<server>,<port>;DATABASE=StockDB;
UID=<read from backend/.env>;PWD=<read from backend/.env>;
Encrypt=yes;TrustServerCertificate=yes;
```

Do not respond to this failure by cycling through old ODBC drivers, changing
to a non-TLS connection, or changing the SQL query. Those variants were
tested and do not solve the restricted-client Schannel failure. Do not log the
UID, password, connection string, or token values. A successful probe should
report only safe metadata such as server/database, row counts, and query
results that contain no credentials.

When a command needs the elevated path, use an approved command prefix such as
`C:\Repo\stocks_collecting\.venv\Scripts\python.exe` or
`powershell.exe -NoProfile`, and explain that the purpose is a read-only SQL
diagnostic. After the connection is proven, diagnose query or schema errors
separately; do not conflate them with the TLS/Schannel failure.
