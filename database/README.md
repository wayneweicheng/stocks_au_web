# Database Migration: Watchlist Logic to SQL Server

This directory contains SQL scripts to migrate the breakout and gap-up watchlist logic from Python to SQL Server stored procedures.

## Overview

The watchlist calculations have been moved from Python to SQL Server for better performance and data persistence. The logic is now executed as stored procedures and results are stored in dedicated tables.

## Files

1. **001_create_watchlist_tables.sql** - Creates result tables for storing watchlist data
2. **002_create_breakout_watchlist_sp.sql** - Creates stored procedure for breakout watchlist calculations
3. **003_create_gap_up_watchlist_sp.sql** - Creates stored procedure for gap-up watchlist calculations

## Deployment Instructions

### Step 1: Run SQL Scripts

Execute the scripts in order on your SQL Server database:

```sql
-- 1. Create tables
USE StockDB;
GO
-- Execute: 001_create_watchlist_tables.sql

-- 2. Create breakout watchlist stored procedure
-- Execute: 002_create_breakout_watchlist_sp.sql

-- 3. Create gap-up watchlist stored procedure
-- Execute: 003_create_gap_up_watchlist_sp.sql
```

### Step 2: Initial Data Population

After creating the stored procedures, populate data for recent dates:

```sql
-- Populate breakout watchlist for a specific date
EXEC StockDB.Transform.usp_CalculateBreakoutWatchlist @ObservationDate = '2026-01-10';

-- Populate gap-up watchlist for a specific date
EXEC StockDB.Transform.usp_CalculateGapUpWatchlist @ObservationDate = '2026-01-10';
```

### Step 3: Optional - Schedule Daily Execution

Create SQL Server Agent jobs to run these stored procedures daily:

```sql
-- Example: Run every weekday at 7 PM (after market close)
-- This ensures fresh data is available each day
```

## Changes Summary

### Backend Changes

**Breakout Watchlist ([breakout_watchlist.py](../backend/app/routers/breakout_watchlist.py))**:
- Removed complex Python analysis logic (~400 lines)
- Now queries pre-computed results from `StockDB.Transform.BreakoutWatchlist` table
- Added `refresh` parameter to recalculate data on-demand
- Fixed parameters (no longer query parameters):
  - Min Turnover: $500,000
  - Min % Gain: 8.0%
  - Max Price: $5.00
  - Max Day 2 Increase: 20.0%

**Gap-Up Watchlist ([gap_up_watchlist.py](../backend/app/routers/gap_up_watchlist.py))**:
- Removed complex Python analysis logic (~200 lines)
- Now queries pre-computed results from `StockDB.Transform.GapUpWatchlist` table
- Added `refresh` parameter to recalculate data on-demand
- Fixed parameters (no longer query parameters):
  - Gap %: 6.0%
  - Volume Multiplier: 5.0x
  - Min Volume Value: $600,000
  - Min Price: $0.02
  - Close Location: 0.5

### Frontend Changes

**Breakout Watchlist ([frontend/src/app/breakout-watchlist/page.tsx](../frontend/src/app/breakout-watchlist/page.tsx))**:
- Parameters now displayed as read-only (greyed out)
- Added "Refresh Data" button to trigger stored procedure execution
- Simplified API call (only `date` and `refresh` parameters)

**Gap-Up Watchlist ([frontend/src/app/gap-up-watchlist/page.tsx](../frontend/src/app/gap-up-watchlist/page.tsx))**:
- Parameters now displayed as read-only (greyed out)
- Added "Refresh Data" button to trigger stored procedure execution
- Simplified API call (only `date` and `refresh` parameters)

## Benefits

1. **Performance**: SQL Server processes complex pattern analysis much faster than Python
2. **Data Persistence**: Results are stored and can be queried without recalculation
3. **Consistency**: Same logic executed for all users, no client-side parameter variations
4. **Maintainability**: Logic is centralized in SQL stored procedures
5. **Scalability**: Can be scheduled to run daily via SQL Server Agent
6. **Historical Tracking**: Results table includes `CreatedAt` timestamp for audit trail

## Testing

1. **Test Stored Procedures**:
   ```sql
   -- Test breakout watchlist
   EXEC StockDB.Transform.usp_CalculateBreakoutWatchlist @ObservationDate = '2026-01-10';

   -- Verify results
   SELECT * FROM StockDB.Transform.BreakoutWatchlist WHERE ObservationDate = '2026-01-10';

   -- Test gap-up watchlist
   EXEC StockDB.Transform.usp_CalculateGapUpWatchlist @ObservationDate = '2026-01-10';

   -- Verify results
   SELECT * FROM StockDB.Transform.GapUpWatchlist WHERE ObservationDate = '2026-01-10';
   ```

2. **Test Backend API**:
   ```bash
   # Test breakout watchlist (read from table)
   curl "http://localhost:3101/api/breakout-watchlist?date=2026-01-10"

   # Test with refresh (execute stored procedure)
   curl "http://localhost:3101/api/breakout-watchlist?date=2026-01-10&refresh=true"

   # Test gap-up watchlist (read from table)
   curl "http://localhost:3101/api/gap-up-watchlist?date=2026-01-10"

   # Test with refresh (execute stored procedure)
   curl "http://localhost:3101/api/gap-up-watchlist?date=2026-01-10&refresh=true"
   ```

3. **Test Frontend**:
   - Navigate to the Breakout Watchlist page
   - Verify parameters are greyed out (read-only)
   - Click "Refresh Data" button to recalculate
   - Change date and verify results load from database

## Rollback Plan

If issues arise, you can revert to the old Python-based logic by:

1. Restoring the original router files from git history
2. Frontend will automatically work with restored routers (parameters will become editable again)
3. SQL tables and stored procedures can remain (they won't interfere)

## Future Enhancements

1. Create SQL Server Agent jobs for daily automated execution
2. Add data retention policy (e.g., keep last 90 days)
3. Add performance indexes if queries become slow
4. Consider creating similar stored procedures for US markets
5. Add stored procedure for batch processing (e.g., calculate last 30 days at once)
