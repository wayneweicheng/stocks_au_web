# Task 05: Harden Notification Publishing and Pushover Delivery

## Objective

Connect committed Trading Signal Notification Events to the existing Pushover infrastructure without duplicate queueing, concurrent sends, mutable report links, or unsafe retries.

The runtime publishes notification intent; the generic handler delivers it. Strategy Implementations never call Pushover.

## Prerequisites

- Tasks 02, 03, and 04 are complete.
- Confirm `StockDB` and `StockDB_US` are on the same SQL Server instance.
- Existing notification users/subscriptions and announcement delivery behavior are understood.

If the databases are on different SQL Server instances, stop. Do not introduce a distributed transaction. Propose a relay-outbox task instead.

## Repository

`C:\Repo\stocks_collecting`

## Existing files to preserve and improve

- `DatabaseSchema/StockDB/Tables/Notification/MessageQueue.sql`
- `DatabaseSchema/StockDB/StoredProcedures/Notification/usp_QueueMessage.sql`
- `DatabaseSchema/StockDB/StoredProcedures/Notification/usp_UpdateMessageStatus.sql`
- `DatabaseSchema/StockDB/StoredProcedures/Notification/usp_GetPendingMessages.sql`
- `src/notification_handler/generic_notification_handler.py`
- `src/notification_handler/generic_notification_handler.bat`
- `src/publishers/base_publisher.py`

Changes must remain backward-compatible for non-strategy notifications.

## MessageQueue schema changes

Add idempotently:

- `IdempotencyKey nvarchar(200) NULL`;
- `LeaseOwner nvarchar(100) NULL`;
- `LeaseExpiresDate datetime2 NULL`;
- `DeliveryStateDetail nvarchar(50) NULL` if needed to represent ambiguity clearly;
- an appropriate `rowversion` if status updates use compare-and-set.

Add a filtered unique index on non-null `IdempotencyKey`.

Do not make the new column non-null for historical rows. New Trading Signal messages must always provide it.

## Queue procedure changes

Update `usp_QueueMessage` to accept `@pnvchIdempotencyKey`.

Behavior:

- In one transaction, return the existing Message ID when the key already exists.
- Never insert a second row for the same key.
- Preserve existing behavior for callers that pass NULL.
- Return whether the row was created or reused.
- Do not use a five-minute duplicate window; identity is permanent.

Add `usp_ClaimPendingMessages`:

- parameters: worker, channel/event filter, batch size, lease seconds;
- use `UPDLOCK`, `READPAST`, `ROWLOCK` in one transaction;
- select `PENDING` or safe `RETRY_WAITING` rows whose schedule is due;
- reclaim expired `PROCESSING` rows only when prior delivery was not ambiguous;
- update claimed rows to `PROCESSING` with lease owner/expiry;
- return exactly the rows claimed by this worker;
- deterministic order: priority descending, scheduled date ascending, Message ID ascending.

Do not select pending rows and update them later in Python.

## Cross-database publication transaction

Extend the Task 04 evaluation/lifecycle transaction so a user-facing Notification Event causes a corresponding insert/reuse in:

```text
[StockDB].[Notification].[MessageQueue]
```

in the same SQL connection transaction that commits:

- domain state;
- Report Snapshot;
- `StockDB_US.TradingSignal.NotificationEvent`;
- Notification Delivery projection;
- MessageQueue row;
- successful Strategy Run.

The queue row must include:

- deterministic idempotency key copied from Notification Event;
- Event Type prefixed consistently, for example `TRADING_SIGNAL_ENTER`;
- Event Source ID referencing Notification Event public/stable identity;
- Event Source Table identifying `StockDB_US.TradingSignal.NotificationEvent`;
- title/body;
- immutable report URL in `MessageURL`;
- structured metadata containing notification type, strategy, version, Instrument, report public ID, and optional Pushover sound;
- explicit target user or subscription context;
- channel `pushover`;
- approved priority.

If queue insertion fails, the Strategy Run transaction must roll back. Do not commit a user-facing event that can never be published.

## Report URL rules

Construct URLs in the runtime publishing Module, not the Strategy Implementation:

```text
{TRADING_SIGNAL_REPORT_BASE_URL}/trading-signal-reports?public_report_id={public_report_id}
```

Pushover must open the authenticated website catalog, not the immutable HTML API endpoint. The catalog preserves the opaque report ID, fetches the HTML with the signed-in user's application credentials, and renders it in the sandboxed viewer. Do not put the shared report token in notification URLs.

Set Pushover `url_title` to `Open trading signal report`. Do not duplicate the raw URL in the message body.

## Handler refactor

Refactor `GenericNotificationHandler` to provide:

- `run_once(...)` for one claimed batch;
- existing `run_forever(...)` behavior as the backward-compatible default;
- optional channel/event filters;
- atomic claims through `usp_ClaimPendingMessages`;
- lease owner passed to status updates;
- safe recovery of expired claims;
- no direct `SELECT Status='pending'` path.

Treat `StockDB.Notification.MessageQueue` as the transport work queue and `StockDB_US.TradingSignal.NotificationDelivery` as the domain-visible delivery projection. For Trading Signal rows:

- claim/reclaim must synchronize the projection's lease/state using a tightly scoped `TradingSignal` procedure or the same cross-database transaction;
- every terminal/retry/unknown queue status update and its Notification Delivery update commit in one SQL connection transaction;
- correlate by the stored Queue Message ID plus Notification Event identity, not title/body matching;
- non-strategy queue rows retain their existing behavior and do not require a TradingSignal row;
- if the provider may have accepted a request but the status transaction cannot commit, lease recovery must classify the outcome as `DELIVERY_UNKNOWN`, not resend it.

Add CLI options without breaking the current no-argument command:

```text
--once
--channel pushover
--event-prefix TRADING_SIGNAL_
--batch-size N
--worker-id VALUE
```

## Delivery outcome policy

Classify outcomes conservatively:

- `SENT`: Pushover returned a successful JSON response; store request ID.
- `RETRY_WAITING`: failure known to occur before provider acceptance, such as DNS failure, connection refused, or connect timeout; increment retry count and schedule backoff.
- `FAILED`: explicit non-retryable provider rejection or retries exhausted.
- `DELIVERY_UNKNOWN`: read timeout, connection reset after request transmission, malformed success response, or process recovery from a lease where provider acceptance cannot be disproved.
- `SKIPPED`: no valid recipient or channel disabled.

Never automatically retry `DELIVERY_UNKNOWN`. Preserve it for operator reconciliation.

Use bounded exponential backoff for safe retries. Do not retry in a blocking loop inside one handler call.

## Notification levels

The common policy supports:

- information: persist only by default;
- watch: normal Pushover priority;
- entry: high priority;
- position management: high priority;
- data error: high priority, deduplicated by run/data-error identity.

Pushover emergency priority requiring acknowledgement is not enabled unless separately requested.

## Tests

Add unit and SQL integration tests covering:

- same Notification Event queued twice produces one MessageQueue row;
- strategy transaction rolls back when cross-database queue insert fails;
- two handlers racing claim disjoint message sets;
- expired safe claim can be reclaimed;
- ambiguous claim is not reclaimed automatically;
- report URL is immutable and token encoded;
- token is absent from logs;
- connect failure schedules retry;
- read timeout becomes `DELIVERY_UNKNOWN`;
- successful Pushover response stores provider request ID;
- MessageQueue and NotificationDelivery states stay synchronized for success, retry, failure, skip, and unknown outcomes;
- simulated provider success followed by database status failure becomes unknown on recovery and is not resent;
- no subscriber becomes `SKIPPED` without retry storm;
- existing NULL-idempotency announcement publisher remains functional;
- default forever-loop behavior still invokes repeated `run_once` calls.

Use a recording/failing HTTP Adapter; unit tests must not call Pushover.

## Acceptance criteria

- Trading Signal queueing is transactionally coupled to its Report Snapshot and state change.
- Unique database constraints prevent duplicate queue rows.
- Pending rows are atomically claimed.
- Ambiguous Pushover delivery is visible and never automatically retried.
- Queue transport state and the Trading Signal delivery projection reconcile by stable IDs.
- Existing generic notification event types remain supported.
- Every Trading Signal Pushover message has an immutable report URL.
- No Strategy Implementation imports the notification handler or `requests`.

## Out of scope

- Changing user subscription semantics beyond what Trading Signals require.
- Adding SMS, Discord, or email.
- Actual Pushover sends during tests.
- SPX/META wording; those are strategy tasks.

## Verification

```powershell
Set-Location C:\Repo\stocks_collecting
poetry run pytest tests\strategy_runtime\test_notification_publisher.py -q
poetry run pytest tests\notification_handler -q
poetry run python src\notification_handler\generic_notification_handler.py --help
git diff --check
```

Run SQL concurrency tests only against an approved database and include the database name in the handoff.

## Required handoff evidence

- MessageQueue migration details.
- Claim procedure behavior and race-test output.
- Failure classification tests.
- Cross-database rollback evidence.
- Confirmation that legacy notification paths still pass their tests.
