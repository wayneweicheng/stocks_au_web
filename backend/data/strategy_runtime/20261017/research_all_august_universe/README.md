# All August 2026 GEX universe research

Universe source: `StockDB_US.Analysis.GEX_Features` with `ObservationDate >= 2026-08-01` and `< 2026-09-01`.

The query returned 91 symbols, including `_VIX.US`; `_VIX.US` was excluded as non-tradable, leaving 90 instruments. Eighty-eight had 30-minute execution bars through the cutoff. Research outcomes use only data resolved by 2026-08-31. September and October 2026 remain reserved for independent validation.

## Option quote timing convention

- `ObservationDate` is the authoritative US trading date of the option data.
- `CreateDate` is the insert-system timestamp and must not be used to relabel the observation date.
- `LastTradeTime` is the option's last trade time in the source US timezone; it is not the snapshot publication timestamp.
- Open interest is treated under the supplied convention: commonly available on the second Sydney date between 20:00 and 23:00. A quote-based production predicate must map that schedule to the D1 07:30 America/New_York readiness gate and fail closed when the schedule is not satisfied.

Quote data was not necessary for the first universe-wide candidate scan; this is not a claim that it is unusable.
