# Signal Strength Source Type Migration

## Problem

The Market Signal Strength Matrix on the Market Flow Signals page was showing mixed data from two different analysis sources:
- **GEX-based signals** (US stocks analyzed via Market Flow Signals)
- **Breakout Analysis signals** (ASX stocks analyzed via Breakout Consolidation Analysis)

This caused confusion because US market GEX signals were being mixed with ASX breakout patterns.

## Solution

Added a `SourceType` column to the `SignalStrength` table to distinguish between:
- `GEX` - Market Flow Signals (US stocks with GEX, VIX, Dark Pool analysis)
- `BREAKOUT` - Breakout Consolidation Analysis (ASX stocks with breakout patterns)

## Migration Steps

### 1. Run the SQL Migration Script

Execute the migration script to add the `SourceType` column:

```bash
# Using SQL Server Management Studio (SSMS):
# Open and execute: backend/sql/add_source_type_to_signal_strength.sql

# Or using sqlcmd:
sqlcmd -S <server> -d StockDB_US -i backend/sql/add_source_type_to_signal_strength.sql
```

This script will:
1. Add the `SourceType` column
2. Set existing records to `GEX` (assumes existing data is from Market Flow Signals)
3. Update the primary key to include `SourceType`
4. Update indexes for performance
5. Add validation constraint

### 2. Restart the Backend

After running the migration, restart the FastAPI backend:

```bash
cd backend
# Kill existing process
# Restart using your preferred method
uvicorn app.main:app --reload --port 3101
```

### 3. Verify the Changes

#### Check the Database
```sql
-- Verify column exists
SELECT TOP 5 * FROM Analysis.SignalStrength;

-- Should see columns: ObservationDate, StockCode, SignalStrengthLevel, SourceType, CreatedAt, UpdatedAt

-- Check source type distribution
SELECT SourceType, COUNT(*) as Count
FROM Analysis.SignalStrength
GROUP BY SourceType;
```

#### Test the API
```bash
# Get all signal strengths
curl "http://localhost:3101/api/signal-strength?observation_date=2025-01-14"

# Get only GEX signals
curl "http://localhost:3101/api/signal-strength?observation_date=2025-01-14&source_type=GEX"

# Get only BREAKOUT signals
curl "http://localhost:3101/api/signal-strength?observation_date=2025-01-14&source_type=BREAKOUT"
```

### 4. Frontend Changes

The Market Flow Signals page now automatically filters to show only `GEX` source signals:
- Market Signal Strength Matrix will only show US stocks analyzed via GEX signals
- Breakout Analysis signals (ASX stocks) will not appear in this matrix
- This ensures clean separation between the two analysis types

## Code Changes Summary

### Backend
1. **Database Schema** - Added `SourceType` column with constraint
2. **SignalStrengthDBService** - All methods now support `source_type` parameter
3. **Price Predictions Router** - Specifies `source_type="GEX"` when saving
4. **Breakout Analysis Router** - Specifies `source_type="BREAKOUT"` when saving
5. **Signal Strength API** - Added optional `source_type` query parameter

### Frontend
1. **Market Flow Signals Page** - Filters API requests to `source_type=GEX`

## Rollback (if needed)

If you need to rollback the migration:

```sql
-- WARNING: This will lose the SourceType distinction

-- Drop the new constraint
ALTER TABLE Analysis.SignalStrength
DROP CONSTRAINT CK_SignalStrength_SourceType;

-- Drop the new primary key
ALTER TABLE Analysis.SignalStrength
DROP CONSTRAINT PK_SignalStrength;

-- Recreate old primary key (without SourceType)
ALTER TABLE Analysis.SignalStrength
ADD CONSTRAINT PK_SignalStrength PRIMARY KEY (ObservationDate, StockCode);

-- Drop the column (this will delete all BREAKOUT source data!)
ALTER TABLE Analysis.SignalStrength
DROP COLUMN SourceType;

-- Recreate old indexes
CREATE INDEX IX_SignalStrength_ObservationDate ON Analysis.SignalStrength(ObservationDate);
CREATE INDEX IX_SignalStrength_StockCode ON Analysis.SignalStrength(StockCode);
```

## Benefits

1. **Clean Data Separation** - GEX and Breakout signals are clearly separated
2. **No Data Loss** - Existing data is preserved and categorized
3. **Future Extensibility** - Easy to add new source types in the future
4. **Better UX** - Users see only relevant signals for each analysis type
5. **API Flexibility** - Can query by source type or get all sources

## Notes

- Existing signal strength data (before migration) will be tagged as `GEX` source type
- If you had ASX stocks in the signal strength table before this migration, they will incorrectly be tagged as `GEX`. You may want to manually clean this up or regenerate those predictions.
- Going forward, all new predictions will be correctly tagged based on their source
