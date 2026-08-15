# Task 09: Build the General Trading Signal Reports Page

## Objective

Replace the SPX-only report browsing experience with a generic Trading Signal Reports page that can display SPX, META, and future strategies without frontend code changes for each classification.

## Prerequisites

- Task 08 is complete and its API contract is stable.
- At least two SPX report kinds and a superseded-revision example are available as fixtures.

## Repository and file areas

Repository: `C:\Repo\stocks_au_web`

Create or update:

```text
frontend\src\app\trading-signal-reports\page.tsx
frontend\src\app\spx-gex-reports\page.tsx
frontend\src\app\components\NavigationMenu.tsx
frontend\src\app\components\AppShell.tsx
frontend\src\lib\api\trading-signal-reports.ts
frontend\src\components\trading-signal-reports\...
```

Follow the repository's existing component, API-client, styling, and testing conventions. Reuse the current SPX report viewer where it is generic enough; do not copy a second large viewer.

## Route and compatibility behavior

- Add the canonical route `/trading-signal-reports`.
- Change navigation text to `Trading Signal Reports` and link it to the canonical route.
- Keep `/spx-gex-reports` functional by redirecting to the canonical page with `strategy_code=spx-gex`, or by rendering a thin wrapper that uses the same generic component.
- Preserve supported query parameters during redirects.
- Do not break immutable HTML URLs opened directly from Pushover; those are backend routes and must not require client-side routing.

## Page behavior

Provide:

- date-from/date-to filters;
- Strategy, Instrument, Environment, and report-kind filters populated from returned/catalog metadata or stable API options;
- free-text search with a deliberate submit/debounce policy;
- a paginated report list using the opaque cursor;
- selected-report metadata and immutable HTML viewer;
- clear current/superseded/revision display;
- explicit empty, loading, partial-loading, unauthorized, not-found, and service-unavailable states.

The default selection should be the newest current report in the current filter set. Do not automatically switch the user's selection when a background refresh discovers a newer report.

Keep filtering server-side. Do not fetch the whole report history or HTML for every list row.

## Report viewer security

Render stored HTML in an `iframe` with the narrowest practical `sandbox` policy. Do not use `dangerouslySetInnerHTML` in the parent application. The iframe URL is the API-provided immutable URL.

- Give the iframe an accessible title derived from safe metadata.
- Do not grant top navigation, popups, same-origin script privileges, camera, microphone, clipboard, or downloads unless an existing report demonstrably requires one and the exception is reviewed.
- Keep the token, when required, in the iframe URL returned/constructed by the authenticated backend contract; do not log or display it.
- Show a separate `Open report` action that opens the immutable resource, not `latest`.

## Generic rendering rules

The React page renders catalog metadata only. Strategy-specific decision metrics, classifications, tables, and explanations remain inside each stored HTML Report Snapshot.

Do not add:

- `if strategy_code === 'spx-gex'` classification layouts;
- client-side trading calculations;
- buttons that run/retry/correct a strategy;
- live quote polling;
- assumptions that the subject and execution Instrument are the same.

Small presentation differences such as an SPX compatibility page title are allowed in the legacy wrapper only.

## URL state and accessibility

- Reflect shareable filter values and selected public report ID in query parameters.
- Validate URL parameters and fall back safely when a report no longer matches filters.
- Browser back/forward must restore filters and selection.
- Use labeled controls, keyboard-accessible report rows, visible focus, and appropriate live regions for loading/errors.
- Dates must state the report market timezone or use unambiguous ISO dates; generated timestamps should show timezone.

## Tests and manual checks

Cover at minimum:

- initial newest-report selection;
- all filters and cursor pagination;
- selected report preserved during background refresh;
- direct URL to a public report ID;
- legacy SPX route and query preservation;
- current versus superseded badges;
- empty/401/404/503 states;
- iframe sandbox attributes and immutable URL;
- keyboard navigation and accessible labels;
- generic fixtures for a non-SPX strategy without code changes.

Manually check desktop and narrow/mobile widths. The report HTML itself may be wide, but the catalog controls and selection list must remain usable.

## Acceptance criteria

- One page browses reports for arbitrary Strategy Codes and Instruments.
- `/spx-gex-reports` remains usable and lands on SPX-filtered content.
- No strategy calculation or classification rendering was added to React.
- HTML is isolated in a sandboxed iframe.
- `npm run lint` and production build pass.
- Navigation and direct notification links work in the deployed base-path configuration.

## Out of scope

- Editing or deleting reports.
- Strategy run controls.
- Live trading dashboards.
- Changing report HTML templates.
- Removing backend legacy aliases before Task 12.

## Verification

```powershell
Set-Location C:\Repo\stocks_au_web\frontend
npm run lint
npm run build

Set-Location C:\Repo\stocks_au_web
rg -n "spx|green|yellow|GEX" frontend\src\app\trading-signal-reports frontend\src\components\trading-signal-reports frontend\src\lib\api\trading-signal-reports.ts
git diff --check
```

Any `rg` match must be limited to fixture/example data or documented legacy routing, not generic component behavior.

## Required handoff evidence

- Screenshots of desktop and narrow layouts.
- Route/query examples for canonical and legacy pages.
- iframe sandbox value and rationale.
- Lint/build/test output.
- Confirmation that a synthetic non-SPX catalog item renders without component changes.

