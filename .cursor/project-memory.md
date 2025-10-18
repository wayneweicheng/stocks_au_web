# Stocks AU Web - Project Memory

## Project Overview

**Name**: Australian Stocks Trading Application (stocks_au_web)  
**Type**: Full-stack web application for ASX (Australian Stock Exchange) trading tools  
**Purpose**: Dashboard and management system for stock analysis, conditional orders, technical analysis, and investment opportunities

## Architecture

### Tech Stack

**Frontend**:
- Next.js 15 (App Router) with TypeScript
- React 19
- Tailwind CSS 4 for styling
- ESLint with Next.js configuration
- Runs on port **3100**

**Backend**:
- FastAPI (Python)
- Uvicorn ASGI server
- SQL Server database via pyodbc
- Pydantic for settings and validation
- Custom utility library: `arkofdata-common` (from GitHub)
- Runs on port **3101**

**Database**:
- Microsoft SQL Server
- Two primary databases: `StockData` and `StockDB`
- Uses stored procedures for most operations
- Schemas: `[StockData]`, `[Order]`

## Directory Structure

```
stocks_au_web/
├── backend/
│   ├── app/
│   │   ├── main.py           # FastAPI app entry point
│   │   ├── core/
│   │   │   ├── config.py     # Pydantic settings (SQL Server config)
│   │   │   └── db.py         # Database connection utilities
│   │   └── routers/          # API endpoints
│   │       ├── auth.py
│   │       ├── order_book.py
│   │       ├── ta_scan.py
│   │       ├── monitor_stocks.py
│   │       ├── conditional_orders.py
│   │       ├── pegasus_invest_opportunities.py
│   │       └── diagnostics.py
│   ├── .env                  # Environment variables (not in git)
│   └── requirements.txt      # Python dependencies
├── frontend/
│   └── src/
│       └── app/
│           ├── layout.tsx    # Root layout with auth & navigation
│           ├── page.tsx      # Home dashboard
│           ├── contexts/
│           │   └── AuthContext.tsx  # Authentication state
│           ├── components/
│           │   ├── AuthWrapper.tsx
│           │   ├── ClientLayout.tsx
│           │   ├── LoginForm.tsx
│           │   └── NavigationMenu.tsx
│           ├── utils/
│           │   └── authenticatedFetch.ts  # API client with auth
│           └── [feature-pages]/
│               └── page.tsx
├── legacy/                   # Old C# and Python Streamlit code (not active)
├── venv/                     # Python virtual environment
├── logs/                     # Application logs
├── start-apps.ps1           # PowerShell startup script
└── stop-apps.ps1            # PowerShell stop script
```

## Backend Details

### Main Configuration (`backend/app/core/config.py`)
- Uses Pydantic Settings with `.env` file
- Supports multiple environment variable name aliases for flexibility
- Default ODBC Driver: "ODBC Driver 18 for SQL Server"
- Connection timeout: 30 seconds
- Exports environment variables for `arkofdata-common` compatibility

### Database Helper (`backend/app/core/db.py`)
- Function: `get_sql_model()` returns `SQLServerModel` instance
- Uses `arkofdata_common.SQLServerHelper.SQLServerHelper`
- Configured to use `StockData` database by default (can be overridden)

### API Routers & Endpoints

All routers use prefix `/api` except auth which uses `/auth`.

**1. Authentication (`/auth`)**:
- `POST /auth/login` - Login with username/password
- Uses Basic Auth for API authentication
- Credentials stored in environment variables (`ADMIN_USERNAME`, `ADMIN_PASSWORD`)
- Frontend stores credentials in sessionStorage

**2. Order Book (`/api`)**:
- `GET /api/stocks` - Get ASX stock list (calls `[StockData].[usp_GetFirstBuySellStockList]`)
- `GET /api/transactions?date_from={date}&code={code}` - Get transaction history (calls `[StockData].[usp_GetFirstBuySell]`)

**3. Conditional Orders (`/api/conditional-orders`)**:
- `GET /api/conditional-orders` - List all orders (calls `[Order].[usp_GetOrder]`)
- `POST /api/conditional-orders` - Create new order (calls `[Order].[usp_AddOrder]`)
- `PUT /api/conditional-orders/{order_id}` - Update order (calls `[Order].[usp_UpdateOrder]`)
- `DELETE /api/conditional-orders/{order_id}` - Delete order (calls `[Order].[usp_DeleteOrder]`)
- `GET /api/conditional-orders/categories` - Returns ["Stock"]
- `GET /api/conditional-orders/accounts` - Returns ["huanw2114"]
- Database: `StockDB`
- Trade account hardcoded: `huanw2114`

**Order Types Supported**:
1. Sell Open Price Advantage (ID: 9)
2. Sell Close Price Advantage (ID: 13)
3. Sell at bid above (ID: 1)
4. Sell at bid under (ID: 6)
5. Buy Open Price Advantage (ID: 12)
6. Buy Close Price Advantage (ID: 8)
7. Buy at ask above (ID: 7)
8. Buy at bid under (ID: 10)

**4. Other Routers**:
- TA Scan (`ta_scan.py`) - Technical analysis scanning
- Monitor Stocks (`monitor_stocks.py`) - Stock watchlist monitoring
- Pegasus Invest Opportunities (`pegasus_invest_opportunities.py`) - Investment analysis
- Diagnostics (`diagnostics.py`) - System health checks

### CORS Configuration
- Configured in `main.py`
- Allows origins from `allowed_origins` env var
- Default: `http://localhost:3100`
- Allows all methods and headers
- Credentials enabled

## Frontend Details

### Authentication System
- Context-based auth (`AuthContext`)
- Stores credentials in sessionStorage as JSON
- Uses Basic Auth for API calls
- `authenticatedFetch` utility automatically adds auth headers
- Login form appears when not authenticated
- `AuthWrapper` protects all pages

### Pages & Routes

**Home Page (`/`)**:
- Dashboard with system status
- Feature cards linking to all sections
- Health check to backend `/healthz`

**Order Book (`/order-book`)**:
- View ASX stock transactions
- Order book data

**TA Scan (`/ta-scan`)**:
- Technical analysis scanning tools

**Monitor Stocks (`/monitor-stocks`)**:
- Stock watchlist tracking

**Conditional Orders (`/conditional-orders`)**:
- Full CRUD interface for conditional orders
- Form with dynamic fields based on order type
- Buy orders: `order_value` enabled, `order_volume` disabled
- Sell orders: `order_volume` enabled, `order_value` disabled
- Default valid_until: +60 days from creation
- Edit functionality with form pre-population
- Delete with confirmation dialog

**Pegasus Invest Opportunities (`/pegasus-invest-opportunities`)**:
- Investment opportunities and analysis

### UI Styling
- Tailwind CSS with emerald/green gradient theme
- Responsive design (sm/lg breakpoints)
- Backdrop blur effects on header
- Fixed header with navigation
- Modern card-based layouts

## Environment Configuration

### Backend `.env` (in `backend/` directory)
```env
# SQL Server - supports both naming conventions
sqlserver_server=          # or sql_server_host
sqlserver_port=1433        # or sql_server_port
sqlserver_database=        # or sql_server_database
sqlserver_username=        # or sql_server_user
sqlserver_password=        # or sql_server_password

# CORS
allowed_origins=http://localhost:3100

# Auth
ADMIN_USERNAME=admin
ADMIN_PASSWORD=password123
```

### Frontend `.env` (in `frontend/` directory)
```env
NEXT_PUBLIC_BACKEND_URL=http://localhost:3101
```

## Development Workflow

### Starting Applications

**Option 1: PowerShell Script (Recommended)**
```powershell
.\start-apps.ps1
```
- Starts both services in background
- Auto-restart on crashes (max 5 restarts per service)
- Restart cooldown: 60 seconds
- Logs to `logs/` directory with timestamps
- Health monitoring every 30 seconds
- Kills any existing processes on ports first
- Tracks PIDs for clean shutdown

**Option 2: Manual Start**

Backend:
```bash
cd backend
# Activate venv first
uvicorn app.main:app --reload --port 3101
```

Frontend:
```bash
cd frontend
npm run dev  # Uses turbopack, port 3100
```

### Stopping Applications
```powershell
.\stop-apps.ps1
```
- Kills processes from PID file
- Searches for project-related node/python processes
- Forcibly frees ports 3100 and 3101
- Uses taskkill for process tree termination

### Build & Production

Frontend:
```bash
npm run build    # Build with turbopack
npm run start    # Production server on port 3100
```

Backend:
```bash
# Standard uvicorn production deployment
uvicorn app.main:app --host 0.0.0.0 --port 3101
```

## Key Patterns & Conventions

### Backend Patterns

1. **Database Queries**:
   - Prefer stored procedures over raw SQL
   - Use `execute_read_query()` or `execute_read_usp()` for SELECT
   - Use `execute_update_usp()` for INSERT/UPDATE/DELETE (ensures commit)
   - Wrap stored procedures with `DECLARE` for output parameters

2. **Error Handling**:
   - Try-catch blocks return empty lists/dicts on error
   - Some endpoints return error messages in response body
   - HTTP exceptions for critical errors

3. **Data Transformation**:
   - Database fields often PascalCase
   - API responses use snake_case
   - Manual field mapping in routers

4. **Date Formats**:
   - Frontend sends: `YYYY-MM-DD` or ISO datetime
   - Backend converts to: `YYYYMMDD` for SQL Server

### Frontend Patterns

1. **API Calls**:
   - Use `process.env.NEXT_PUBLIC_BACKEND_URL` for base URL
   - Protected endpoints use `authenticatedFetch()`
   - Public endpoints (login, health) use regular `fetch()`

2. **State Management**:
   - `useState` for component state
   - `useEffect` for data loading
   - Context for global auth state
   - SessionStorage for auth persistence

3. **Form Handling**:
   - Controlled components with `useState`
   - Form validation using HTML5 attributes
   - Dynamic field enabling/disabling based on order type
   - Loading states with disabled buttons and spinners

4. **UI Feedback**:
   - Error messages in red-bordered boxes
   - Success messages in green-bordered boxes
   - Loading spinners for async operations
   - Confirmation dialogs for destructive actions

## Important Notes

### Database Schema
- Two main databases: `StockData` (read-only data) and `StockDB` (user data)
- Schema prefixes: `[StockData]`, `[Order]`
- Order table: `[Order].[Order]`
- Must use stored procedures for most operations

### Hardcoded Values
- Trade account: `huanw2114` (in conditional orders)
- User ID: `1` (in order creation)
- Categories: `["Stock"]`
- Order type mappings in `conditional_orders.py`

### Legacy Code
- `legacy/` directory contains old C# ASP.NET and Python Streamlit code
- Not actively used but kept for reference
- Includes older versions of conditional orders and monitor stock functionality

### arkofdata-common Library
- Custom utility library from GitHub
- Provides `SQLServerModel` for database operations
- Repository: `wayneweicheng/utilities_arkofdata-common`
- Version: `v0.1.0`
- Methods used:
  - `execute_read_query(sql, params)`
  - `execute_read_usp(sql, params)`
  - `execute_update_usp(sql, params)`

## Logging

- Logs stored in `logs/` directory
- Timestamped log files: `[service]-YYYYMMDD-HHMMSS.log`
- Separate error logs: `[service]-YYYYMMDD-HHMMSS-error.log`
- Startup logs track service initialization
- Backend uses print statements for debugging (output to logs)

## Common Issues & Solutions

1. **Port Already in Use**:
   - Run `.\stop-apps.ps1` to clean up
   - Manually kill processes: `Get-NetTCPConnection -LocalPort 3100/3101`

2. **Database Connection Errors**:
   - Check `.env` file in `backend/` directory
   - Verify SQL Server is running and accessible
   - Check ODBC Driver 18 is installed
   - Verify firewall rules for SQL Server port

3. **Authentication Failures**:
   - Verify `ADMIN_USERNAME` and `ADMIN_PASSWORD` in backend `.env`
   - Clear sessionStorage in browser dev tools
   - Check Basic Auth headers in network tab

4. **Build Errors**:
   - Frontend: Delete `.next/` and run `npm install`
   - Backend: Recreate venv and `pip install -r requirements.txt`
   - Check Node.js and Python versions

## Future Considerations

- Google OAuth integration (code exists but commented out in frontend)
- NextAuth configuration in `env.example`
- Multiple trade account support (currently hardcoded)
- Dynamic order type loading from database
- Real-time stock price updates
- WebSocket integration for live data

