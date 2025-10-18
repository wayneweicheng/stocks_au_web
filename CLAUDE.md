# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Structure

This is a full-stack Australian stocks trading application with:
- **Frontend**: Next.js 15 with TypeScript, Tailwind CSS, running on port 3100
- **Backend**: FastAPI with Python, running on port 3101
- **Database**: SQL Server integration via pyodbc
- **Legacy**: Contains older code (not actively used)

## Common Development Commands

### Frontend (Next.js)
```bash
cd frontend
npm run dev          # Start development server on port 3100 with turbopack
npm run build        # Build for production with turbopack
npm run start        # Start production server on port 3100
npm run lint         # Run ESLint
```

### Backend (FastAPI)
```bash
cd backend
uvicorn app.main:app --reload --port 3101     # Start development server
# OR use the convenience script:
./backend/run.sh     # Starts backend from any location
```

### Start Both Applications
Use the PowerShell script from repository root:
```powershell
.\start-apps.ps1     # Starts both frontend and backend in background
```

## Architecture Overview

### Backend Structure (FastAPI)
- `app/main.py` - Main FastAPI application with CORS middleware
- `app/core/config.py` - Pydantic settings with SQL Server configuration
- `app/core/db.py` - Database connection utilities
- `app/routers/` - API route modules:
  - `auth.py` - Authentication endpoints
  - `order_book.py` - Stock order book data
  - `ta_scan.py` - Technical analysis scanning
  - `monitor_stocks.py` - Stock monitoring functionality
  - `conditional_orders.py` - Conditional trading orders
  - `pegasus_invest_opportunities.py` - Investment opportunities
  - `diagnostics.py` - System diagnostics

Uses `arkofdata-common` utility library from GitHub for shared functionality.

### Frontend Structure (Next.js App Router)
- `src/app/layout.tsx` - Root layout with authentication and navigation
- `src/app/page.tsx` - Home dashboard with feature cards
- `src/app/components/` - Reusable components:
  - `AuthWrapper.tsx` - Authentication state management
  - `ClientLayout.tsx` - Client-side layout wrapper
  - `LoginForm.tsx` - User login interface
  - `NavigationMenu.tsx` - Main navigation
- `src/app/contexts/AuthContext.tsx` - Authentication context provider
- `src/app/utils/authenticatedFetch.ts` - API client with auth
- Page routes: `/order-book`, `/ta-scan`, `/monitor-stocks`, `/conditional-orders`, `/pegasus-invest-opportunities`

### Environment Configuration

Backend requires `.env` file in `backend/` directory with:
```
sqlserver_server=your_server
sqlserver_port=1433
sqlserver_database=your_db
sqlserver_username=your_user
sqlserver_password=your_password
allowed_origins=http://localhost:3100
```

Frontend requires `.env` file in `frontend/` directory with:
```
NEXT_PUBLIC_BACKEND_URL=http://localhost:3101
```

## Key Technologies & Dependencies

### Frontend
- Next.js 15 with App Router and TypeScript
- Tailwind CSS 4 for styling
- React 19 with authentication context
- ESLint with Next.js configuration

### Backend
- FastAPI for API framework
- Uvicorn ASGI server
- SQL Server via pyodbc driver
- Pydantic for settings and validation
- Custom arkofdata-common utilities
- Python virtual environment in `venv/`

## Application Startup Process

The `start-apps.ps1` script manages both services:
1. Kills any existing processes using the ports
2. Starts backend Python server (headless)
3. Starts frontend Next.js server (headless)
4. Logs output to `logs/` directory
5. Maintains PID tracking for clean shutdown

## Development Notes

- Backend uses SQL Server with configurable connection parameters
- Frontend communicates with backend via authenticated API calls
- Both applications support hot reload during development
- CORS is configured to allow frontend-backend communication
- Authentication system is implemented across both frontend and backend