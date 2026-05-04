# Stock Analysis Tab Implementation Plan

## Overview
Add a new "Stock Analysis" tab to the Research Hub page that allows users to generate AI-powered stock analysis reports for ASX-listed stocks. This feature is inspired by the ASX-spec-analyzer skill but implemented as a web-based service using scripts + LLM calls instead of a skill framework.

## Business Requirements

### User Story
As a user analyzing ASX stocks, I want to:
1. Select a stock from my tipped stocks list
2. Choose an observation date for the analysis
3. Generate a comprehensive analysis report that includes:
   - Executive summary
   - Catalyst countdown
   - Technical structure analysis
   - Capital & survival assessment
   - Broker activity analysis
   - Risk assessment
   - Asymmetry matrix
   - Final rating with confidence score

### Key Features
- **Stock Selection**: Dropdown populated from "All Tipped Stocks" (stocks with ratings in Research.StockRating)
- **Date Selection**: Date picker for observation date (as-at date)
- **Processing Status**: Real-time status display (Not Started → Processing → Completed/Error)
- **Report Display**: Markdown-rendered analysis report
- **Report Persistence**: Save reports to database for future retrieval
- **Model Selection**: Choose LLM model (similar to existing features)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                       │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Research Hub Page                                  │  │
│  │  └─ Stock Analysis Tab Component                   │  │
│  │     ├─ Stock Dropdown (All Tipped Stocks)          │  │
│  │     ├─ Date Picker (Observation Date)              │  │
│  │     ├─ Model Selector                              │  │
│  │     ├─ Process Button                              │  │
│  │     ├─ Status Display                              │  │
│  │     └─ Markdown Report Viewer                      │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP/REST API
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Backend (FastAPI)                          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  /api/stock-analysis/* Router                       │  │
│  │  ├─ GET /tipped-stocks                             │  │
│  │  ├─ GET /status/{stock}/{date}                     │  │
│  │  ├─ POST /process                                  │  │
│  │  └─ GET /report/{stock}/{date}                     │  │
│  └─────────────────────────────────────────────────────┘  │
│                         │                                   │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Stock Analysis Service                             │  │
│  │  ├─ data_export.py (SQL queries)                   │  │
│  │  ├─ announcement_compact.py                        │  │
│  │  ├─ price_ta_compact.py                            │  │
│  │  ├─ broker_compact.py                              │  │
│  │  ├─ liquidity_compact.py                           │  │
│  │  ├─ context_builder.py                             │  │
│  │  └─ report_generator.py (LLM integration)          │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              SQL Server (StockDB)                           │
│  ├─ StockData.* (announcements, prices, broker data)       │
│  ├─ Transform.* (broker enhanced tables)                   │
│  └─ Research.* (ratings, reports, processing queue)        │
└─────────────────────────────────────────────────────────────┘
```

## Database Schema

### New Tables

#### Research.StockAnalysisReport
Stores completed analysis reports.

```sql
CREATE TABLE [Research].[StockAnalysisReport] (
    [ReportID] INT IDENTITY(1,1) PRIMARY KEY,
    [StockCode] VARCHAR(20) NOT NULL,
    [ObservationDate] DATE NOT NULL,
    [ReportMarkdown] NVARCHAR(MAX) NULL,
    [ReportJSON] NVARCHAR(MAX) NULL,
    [Model] VARCHAR(100) NULL,
    [Status] VARCHAR(20) NOT NULL DEFAULT 'Completed',
    [ProcessedAt] DATETIME NOT NULL DEFAULT GETDATE(),
    [ProcessedBy] VARCHAR(50) NULL,
    [TokensUsed] INT NULL,
    [ProcessingTimeSeconds] DECIMAL(10,2) NULL,
    UNIQUE ([StockCode], [ObservationDate])
);
```

#### Research.StockAnalysisProcessing
Tracks processing queue and status.

```sql
CREATE TABLE [Research].[StockAnalysisProcessing] (
    [ProcessingID] INT IDENTITY(1,1) PRIMARY KEY,
    [StockCode] VARCHAR(20) NOT NULL,
    [ObservationDate] DATE NOT NULL,
    [Status] VARCHAR(20) NOT NULL DEFAULT 'Pending',
    [StartedAt] DATETIME NULL,
    [CompletedAt] DATETIME NULL,
    [ErrorMessage] NVARCHAR(MAX) NULL,
    [RequestedBy] VARCHAR(50) NULL,
    [Model] VARCHAR(100) NULL,
    UNIQUE ([StockCode], [ObservationDate]) WHERE [Status] IN ('Pending', 'Processing')
);
```

### Existing Tables Used
- `Research.StockRating` - Source for tipped stocks
- `Research.Commenter` - Commenter information
- `StockData.Announcement` - Company announcements
- `StockData.PriceHistory` - Daily price data
- `Transform.StockDayBrokerSetup` - Broker flow setup
- `Transform.BrokerTxMicrostructureDay` - Broker microstructure

## Backend Implementation

### API Endpoints

#### GET /api/stock-analysis/tipped-stocks
Returns list of stocks with ratings.

**Response:**
```json
{
  "items": [
    {
      "stock_code": "BHP.AX",
      "total_ratings": 5,
      "bullish_count": 4,
      "latest_rating_date": "2026-04-15",
      "latest_analysis_date": "2026-04-20"
    }
  ]
}
```

#### POST /api/stock-analysis/process
Trigger analysis for a stock/date combination.

**Request:**
```json
{
  "stock_code": "BHP.AX",
  "observation_date": "2026-04-20",
  "model": "google/gemini-3-flash-preview"
}
```

**Response:**
```json
{
  "processing_id": 123,
  "status": "Processing"
}
```

#### GET /api/stock-analysis/status/{processing_id}
Check processing status.

**Response:**
```json
{
  "status": "Processing",
  "started_at": "2026-04-28T10:00:00",
  "progress": "Generating report..."
}
```

#### GET /api/stock-analysis/report/{stock_code}/{observation_date}
Retrieve completed report.

**Response:**
```json
{
  "report_id": 456,
  "stock_code": "BHP.AX",
  "observation_date": "2026-04-20",
  "report_markdown": "# BHP.AX Analysis...",
  "report_json": {...},
  "processed_at": "2026-04-28T10:05:00"
}
```

### Service Modules

#### 1. data_export.py
Export raw data from SQL Server.

**Functions:**
- `export_announcements(stock_code, observation_date)` → List of announcements (90 days)
- `export_price_history(stock_code, observation_date)` → Daily OHLCV (90 days)
- `export_broker_data(stock_code, observation_date)` → Broker setup + microstructure
- `export_all_data(stock_code, observation_date)` → Complete data bundle

**Key Considerations:**
- Use T+3 cutoff for broker data (observation_date - 3 days)
- Handle both `.AX` suffix and base code formats
- Get latest trading date ≤ observation date

#### 2. announcement_compact.py
Compact announcements to LLM-ready format (~3,000 tokens).

**Output Structure:**
```json
{
  "coverage": {
    "start_date": "2026-01-20",
    "end_date": "2026-04-20",
    "total_count": 15
  },
  "material_events": [
    {
      "date": "2026-04-10",
      "description": "Quarterly Activities Report",
      "market_sensitive": true,
      "category": "funding"
    }
  ],
  "funding_signals": {
    "recent_raise": true,
    "cash_position": "Strong",
    "runway_months": 12
  },
  "catalysts": [
    {
      "type": "explicit",
      "item": "Drill results expected Q2 2026",
      "certainty": "high",
      "timing": "next_90d"
    }
  ],
  "red_flags": []
}
```

#### 3. price_ta_compact.py
Compact price and technical analysis (~2,000 tokens).

**Output Structure:**
```json
{
  "current_price": 2.45,
  "price_change_30d": 15.2,
  "technical_setup": "Breakout",
  "support_levels": [2.20, 2.00],
  "resistance_levels": [2.60, 2.80],
  "volume_trend": "Increasing",
  "momentum": "Strong"
}
```

#### 4. broker_compact.py
Compact broker flow data (~3,000 tokens).

**Output Structure:**
```json
{
  "accumulation_score": 7,
  "top_buyers": ["UBS", "Morgan Stanley"],
  "top_sellers": ["Retail"],
  "net_institutional_flow": "Positive",
  "concentration": "High buyer concentration",
  "microstructure_score": 8
}
```

#### 5. liquidity_compact.py
Compact liquidity metrics (~1,000 tokens).

**Output Structure:**
```json
{
  "avg_daily_volume": 1500000,
  "liquidity_score": 6,
  "median_trade_value": 5000,
  "depth_score": 7
}
```

#### 6. context_builder.py
Build context pack for main LLM context (~1,500 tokens total).

**Output Structure:**
```json
{
  "stock_code": "BHP.AX",
  "observation_date": "2026-04-20",
  "effective_trade_date": "2026-04-19",
  "data_coverage": {
    "announcements": 15,
    "price_days": 90,
    "broker_days": 20
  },
  "quick_summary": "Mining company, strong fundamentals, recent drill results..."
}
```

#### 7. report_generator.py
Generate markdown report using LLM.

**Process:**
1. Load all compact artifacts
2. Load report template (from ASX-spec-analyzer format)
3. Build structured prompt with compact data
4. Call LLM API (OpenRouter or direct)
5. Parse markdown response
6. Extract JSON structured data
7. Save to database

**LLM Prompt Structure:**
```
You are analyzing ASX stock {code} as at {date}.

Use the following compact data to generate a comprehensive analysis report:

1. Context Pack: {context_pack_json}
2. Announcements: {announcement_compact_json}
3. Price/Technical: {price_ta_compact_json}
4. Broker Flow: {broker_compact_json}
5. Liquidity: {liquidity_compact_json}

Generate a report following this template:
{report_template_md}

Apply the following scoring rubric:
- Fundamental: 0-10 (weight 20%)
- Newsflow/Catalyst: 0-10 (weight 30%)
- Technical: 0-10 (weight 20%)
- Broker: 0-10 (weight 30%)

Final Rating Bands:
- 8-10: Strong Buy
- 6-7.99: Buy
- 4-5.99: Hold
- 2-3.99: Sell
- 0-1.99: Strong Sell
```

## Frontend Implementation

### Component Structure

```tsx
// New tab in Research Hub
<StockAnalysisTab>
  <StockSelector />        {/* Dropdown from tipped stocks */}
  <DatePicker />           {/* Observation date */}
  <ModelSelector />        {/* LLM model choice */}
  <ProcessButton />        {/* Trigger analysis */}
  <StatusDisplay />        {/* Processing status */}
  <ReportViewer />         {/* Markdown display */}
</StockAnalysisTab>
```

### State Management

```typescript
const [selectedStock, setSelectedStock] = useState<string>("");
const [observationDate, setObservationDate] = useState<string>("");
const [selectedModel, setSelectedModel] = useState<string>("google/gemini-3-flash-preview");
const [processingStatus, setProcessingStatus] = useState<"idle" | "processing" | "completed" | "error">("idle");
const [processingId, setProcessingId] = useState<number | null>(null);
const [reportMarkdown, setReportMarkdown] = useState<string>("");
const [errorMessage, setErrorMessage] = useState<string>("");
```

### User Flow

1. **Initial Load**
   - Fetch tipped stocks from `/api/stock-analysis/tipped-stocks`
   - Display dropdown with stock codes

2. **Stock Selection**
   - User selects stock from dropdown
   - Check if report already exists for selected stock/date
   - Display "Report exists" or "Generate new report" message

3. **Trigger Analysis**
   - User clicks "Process" button
   - POST to `/api/stock-analysis/process`
   - Receive processing_id
   - Start polling for status

4. **Status Polling**
   - Poll `/api/stock-analysis/status/{processing_id}` every 2 seconds
   - Update status display
   - Stop polling when status is "Completed" or "Error"

5. **Display Report**
   - Fetch report from `/api/stock-analysis/report/{stock}/{date}`
   - Render markdown using MarkdownRenderer component
   - Show metadata (processed date, model used, tokens)

## Data Flow

### Processing Pipeline

```
1. User Request
   ↓
2. Create Processing Record (Status: Pending)
   ↓
3. Export Raw Data
   ├─ Announcements (90 days)
   ├─ Price History (90 days)
   ├─ Broker Data (T+3)
   └─ Technical Indicators
   ↓
4. Compact Data (Reduce tokens)
   ├─ announcement_compact.json (~3K tokens)
   ├─ price_ta_compact.json (~2K tokens)
   ├─ broker_compact.json (~3K tokens)
   ├─ liquidity_compact.json (~1K tokens)
   └─ context_pack.json (~1.5K tokens)
   ↓
5. Build LLM Prompt
   ├─ Load report template
   ├─ Insert compact data
   └─ Add scoring rubric
   ↓
6. Call LLM API
   ├─ Send prompt (~10-12K tokens)
   └─ Receive markdown response
   ↓
7. Save Report
   ├─ Parse markdown
   ├─ Extract structured JSON
   ├─ Save to StockAnalysisReport table
   └─ Update Processing status to Completed
   ↓
8. Return to Frontend
```

## Key Design Decisions

### 1. Token Budget Management
**Problem:** Large raw data exports can exceed LLM context limits.

**Solution:** Multi-stage compacting pipeline
- Raw exports → Compact JSON artifacts
- Main context receives only context_pack.json (1.5K tokens)
- Report writer receives all compact artifacts (~11K tokens total)
- Never send raw SQL results directly to LLM

### 2. Broker Data T+3 Rule
**Problem:** Broker data has reporting lag.

**Solution:**
- Use observation_date - 3 days as broker cutoff
- Query Transform schema (pre-computed broker features)
- Use base code (no `.AX` suffix) for Transform tables

### 3. Date Anchoring
**Problem:** Ensure analysis uses correct historical snapshot.

**Solution:**
- User provides observation_date (as-at date)
- System finds effective_trade_date (latest trading day ≤ observation_date)
- Broker data uses effective_trade_date - 3 days
- All data queries filtered by these anchors

### 4. Report Template Consistency
**Problem:** Free-form LLM output varies in structure.

**Solution:**
- Use fixed template from ASX-spec-analyzer
- Structured prompt with placeholders
- Validate report structure before saving
- Store both markdown and JSON formats

### 5. Async Processing
**Problem:** LLM calls can take 30-60 seconds.

**Solution:**
- Background task processing
- Status polling from frontend
- Processing queue table
- Support for multiple concurrent requests

## Testing Strategy

### Unit Tests
- [ ] Data export functions (mocked DB)
- [ ] Compact functions (sample data)
- [ ] Context builder (JSON validation)
- [ ] Report parser (markdown structure)

### Integration Tests
- [ ] API endpoints (FastAPI TestClient)
- [ ] Database operations (test DB)
- [ ] LLM integration (mocked responses)

### End-to-End Tests
- [ ] Complete flow: select stock → process → view report
- [ ] Error handling: missing data, LLM timeout
- [ ] Report persistence: save and retrieve

### Manual Testing Checklist
- [ ] Select tipped stock from dropdown
- [ ] Choose observation date
- [ ] Trigger processing
- [ ] Verify status updates
- [ ] View completed report
- [ ] Check report quality
- [ ] Verify database records
- [ ] Test error cases

## Deployment Steps

### 1. Database Migration
```sql
-- Run schema creation scripts
sqlcmd -S server -d StockDB -i DatabaseSchema/StockDB/Tables/Research/StockAnalysisReport.sql
sqlcmd -S server -d StockDB -i DatabaseSchema/StockDB/Tables/Research/StockAnalysisProcessing.sql
```

### 2. Backend Deployment
```bash
cd backend
# Install dependencies (if any new ones)
pip install -r requirements.txt
# Restart backend service
uvicorn app.main:app --reload --port 3101
```

### 3. Frontend Deployment
```bash
cd frontend
# Build production bundle
npm run build
# Start production server
npm run start
```

### 4. Verification
- [ ] New tables created in database
- [ ] API endpoints accessible
- [ ] New tab visible in Research Hub
- [ ] Can select stocks and trigger processing
- [ ] Reports generate successfully

## Monitoring & Observability

### Metrics to Track
- Processing requests per day
- Average processing time
- LLM token usage
- Error rate
- Most analyzed stocks
- Model usage distribution

### Logging
- Request/response for each API call
- Processing status changes
- LLM API calls (tokens, latency)
- Errors with stack traces

### Alerts
- Processing failures > 10% in 1 hour
- LLM API timeouts
- Database connection errors

## Future Enhancements

### Phase 2
- [ ] Batch processing (analyze multiple stocks)
- [ ] Scheduled reports (daily/weekly)
- [ ] Email notifications when reports complete
- [ ] Report comparison (stock A vs stock B)
- [ ] Historical report archive

### Phase 3
- [ ] Custom report templates
- [ ] User-defined scoring weights
- [ ] Export to PDF
- [ ] Integration with trading signals
- [ ] Real-time updates (websocket for status)

## Risk Mitigation

### Technical Risks
| Risk | Impact | Mitigation |
|------|--------|-----------|
| LLM API timeout | High | Implement retry logic, increase timeout |
| Token limit exceeded | High | Strict token budgets, multi-stage compacting |
| Database deadlock | Medium | Use transactions carefully, add retry logic |
| Missing historical data | Medium | Graceful degradation, clear error messages |

### Business Risks
| Risk | Impact | Mitigation |
|------|--------|-----------|
| Inaccurate analysis | High | Disclaimer, confidence scores, human review |
| Cost overrun (LLM tokens) | Medium | Token budget limits, caching, rate limiting |
| Poor user adoption | Low | User feedback, iterative improvements |

## Success Criteria

### Functional
- ✅ Users can generate analysis reports for tipped stocks
- ✅ Reports follow consistent structure
- ✅ Processing status is visible
- ✅ Reports are saved and retrievable
- ✅ System handles errors gracefully

### Performance
- ✅ Report generation completes in < 2 minutes
- ✅ API response time < 500ms (excluding LLM calls)
- ✅ Supports concurrent requests (5+ users)

### Quality
- ✅ Reports include all required sections
- ✅ Scoring follows defined rubric
- ✅ Data is accurate and up-to-date
- ✅ No data leakage between stocks

## Timeline Estimate

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| Database | Create tables, indexes | 1 hour |
| Backend - Data Export | SQL queries, data structures | 3 hours |
| Backend - Compacting | 5 compact modules | 4 hours |
| Backend - LLM Integration | Prompt building, API calls | 3 hours |
| Backend - API Endpoints | FastAPI routes, handlers | 2 hours |
| Frontend - Component | React component, state management | 3 hours |
| Frontend - Integration | Add to Research Hub | 1 hour |
| Testing | Unit, integration, E2E | 4 hours |
| Documentation | API docs, user guide | 2 hours |
| **Total** | | **23 hours** |

## References

### ASX-spec-analyzer Inspiration
- Location: `C:\Repo\midas-touch\ASX-spec-analyzer`
- Key concepts: Compact artifacts, token budgets, scoring rubric
- Template: `assets/report_template.md`
- Rubric: `references/report-rubric.md`

### Similar Features in Codebase
- Market Flow page: Admin tab pattern for processing
- Option Recommendations: LLM integration pattern
- Research Hub: Multi-tab interface pattern

### External Dependencies
- OpenRouter API (or direct model APIs)
- SQL Server (StockDB)
- pyodbc (database connector)

---

**Document Version:** 1.0
**Last Updated:** 2026-04-28
**Author:** Claude (AI Assistant)
**Status:** Ready for Implementation
