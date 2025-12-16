# Signal Strength Feature Setup

This document describes the setup process for the Signal Strength classification feature.

## Overview

The Signal Strength feature adds LLM-based classification of market signals into 5 levels:
- **STRONGLY_BULLISH**: Multiple strong buy signals, high conviction upside
- **MILDLY_BULLISH**: Some bullish indicators, positive bias with caveats
- **NEUTRAL**: Conflicting signals, unclear direction
- **MILDLY_BEARISH**: Some bearish indicators, negative bias
- **STRONGLY_BEARISH**: Multiple strong sell signals, high conviction downside

## Database Setup

### Step 1: Create the SignalStrength Table

Run the SQL script to create the table:

```sql
-- Located in: backend/sql/create_signal_strength_table.sql
-- Execute this in your SQL Server database (StockDB_US)
```

You can run this using SQL Server Management Studio (SSMS) or via command line:

```bash
# Using sqlcmd (if available)
sqlcmd -S <server> -d StockDB_US -i backend/sql/create_signal_strength_table.sql

# Or manually copy and execute the contents in SSMS
```

### Step 2: Verify Table Creation

After running the script, verify the table exists:

```sql
SELECT TOP 5 * FROM SignalStrength;

-- Should see columns:
-- ObservationDate, StockCode, SignalStrengthLevel, CreatedAt, UpdatedAt
```

## How It Works

### 1. LLM Prompt Enhancement

When generating price predictions, the system now prepends special instructions to the LLM prompt requesting a signal strength classification in JSON format.

**Template Service**: [backend/app/services/prompt_template_service.py](../app/services/prompt_template_service.py)

### 2. Signal Strength Extraction

After the LLM generates a prediction, the system parses the response to extract the signal strength classification.

**Parser Service**: [backend/app/services/signal_strength_parser.py](../app/services/signal_strength_parser.py)

The parser uses multiple strategies:
- JSON code blocks (```json ... ```)
- Inline JSON objects
- Fallback text pattern matching

### 3. Database Storage

Valid signal strengths are saved to the `SignalStrength` table using an upsert operation (MERGE).

**Database Service**: [backend/app/services/signal_strength_db_service.py](../app/services/signal_strength_db_service.py)

### 4. API Endpoint

Frontend can query all signal strengths for a given observation date.

**Router**: [backend/app/routers/signal_strength.py](../app/routers/signal_strength.py)

**Endpoint**: `GET /api/signal-strength?observation_date=YYYY-MM-DD`

### 5. Frontend Visualization

The GEX Signals page displays a matrix showing all stocks and their signal strength levels with color-coded circles.

**Component**: [frontend/src/app/gex-signals/page.tsx](../../frontend/src/app/gex-signals/page.tsx)

## Usage Flow

1. **Generate Prediction**: User clicks "Generate" or "Regenerate" on the GEX Signals page
2. **LLM Processing**: Backend sends enhanced prompt to LLM with signal strength instructions
3. **Extraction**: System extracts signal strength from LLM response
4. **Storage**: Signal strength is saved to database (upserted if exists)
5. **Display**: Frontend reloads signal strength matrix to show updated classification
6. **Matrix View**: All stocks for the selected date appear in the matrix with color-coded indicators

## Color Coding

- **Solid Green** (bg-emerald-600): STRONGLY_BULLISH
- **Light Green** (bg-emerald-300): MILDLY_BULLISH
- **Amber** (bg-amber-400): NEUTRAL
- **Orange** (bg-orange-400): MILDLY_BEARISH
- **Red** (bg-red-600): STRONGLY_BEARISH

## API Documentation

### Get Signal Strengths

```
GET /api/signal-strength?observation_date=2025-01-15
```

**Response**:
```json
[
  {
    "stock_code": "NVDA",
    "signal_strength_level": "STRONGLY_BULLISH",
    "created_at": "2025-01-15T10:30:00",
    "updated_at": "2025-01-15T10:30:00"
  },
  {
    "stock_code": "SPY",
    "signal_strength_level": "MILDLY_BULLISH",
    "created_at": "2025-01-15T11:00:00",
    "updated_at": "2025-01-15T11:00:00"
  }
]
```

## Troubleshooting

### Signal Strength Not Appearing

1. **Check LLM Output**: Verify that the LLM is actually returning the JSON classification
   - Look at the cached markdown files in `backend/signal_pattern/`
   - Should contain a JSON block at the end with `signal_strength` field

2. **Check Logs**: Backend logs will show extraction success/failure
   ```
   INFO: Extracted signal strength from JSON block: STRONGLY_BULLISH
   INFO: Saved signal strength: NVDA -> STRONGLY_BULLISH
   ```

3. **Database Connection**: Verify that the SignalStrength table exists and is accessible

4. **Regenerate Predictions**: If predictions were generated before this feature was added, click "Regenerate" to update them

### Matrix Not Showing Data

1. **Check API Response**: Open browser DevTools Network tab and verify `/api/signal-strength` returns data
2. **Date Mismatch**: Ensure signal strengths exist for the selected observation date
3. **Authentication**: Ensure user is authenticated (uses same auth as other API calls)

## Future Enhancements

Potential improvements:
- Add trend indicators (arrows showing if signal is strengthening/weakening)
- Historical signal strength charts
- Bulk regeneration tool to populate historical data
- Export signal strength data to CSV
- Alert system when stocks change signal strength levels
