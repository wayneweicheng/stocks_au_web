# Quick Reference Guide

## Essential Commands

### Start/Stop Applications
```powershell
# Start both frontend and backend (recommended)
.\start-apps.ps1

# Stop all services
.\stop-apps.ps1
```

### Manual Development
```bash
# Backend (from repo root)
cd backend
uvicorn app.main:app --reload --port 3101

# Frontend (from repo root)  
cd frontend
npm run dev
```

### Logs
```powershell
# View latest startup log
Get-Content logs\startup-*.log | Select-Object -Last 50

# View backend logs (find latest)
Get-Content logs\backend-*.log -Tail 20 -Wait

# View frontend logs (find latest)
Get-Content logs\frontend-*.log -Tail 20 -Wait
```

## URLs

- **Frontend**: http://localhost:3100
- **Backend**: http://localhost:3101
- **Backend Health**: http://localhost:3101/healthz
- **API Docs**: http://localhost:3101/docs (FastAPI auto-generated)

## Database Quick Reference

### Databases
- `StockData` - Stock market data (read-only)
- `StockDB` - User orders and configuration

### Key Stored Procedures
```sql
-- Order Book
[StockData].[usp_GetFirstBuySellStockList]
[StockData].[usp_GetFirstBuySell] @pdtObservationDate, @pvchStockCode

-- Conditional Orders
[Order].[usp_GetOrder] @pvchTradeAccountName
[Order].[usp_AddOrder] @pvchASXCode, @pintUserID, @pvchTradeAccountName, ...
[Order].[usp_UpdateOrder] @pintOrderID, @pdecOrderPrice, ...
[Order].[usp_DeleteOrder] @pintOrderID
```

## API Endpoints Cheat Sheet

### Authentication
```http
POST /auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "password123"
}
```

### Order Book
```http
GET /api/stocks
GET /api/transactions?date_from=2025-01-31&code=MEK.AX
```

### Conditional Orders
```http
GET /api/conditional-orders
POST /api/conditional-orders
PUT /api/conditional-orders/{order_id}
DELETE /api/conditional-orders/{order_id}
GET /api/conditional-orders/categories
GET /api/conditional-orders/accounts
```

## Environment Files

### backend/.env
```env
sqlserver_server=YOUR_SERVER
sqlserver_port=1433
sqlserver_database=YOUR_DB
sqlserver_username=YOUR_USER
sqlserver_password=YOUR_PASSWORD
allowed_origins=http://localhost:3100
ADMIN_USERNAME=admin
ADMIN_PASSWORD=password123
```

### frontend/.env
```env
NEXT_PUBLIC_BACKEND_URL=http://localhost:3101
```

## Common Tasks

### Add New API Endpoint
1. Create router function in `backend/app/routers/[router].py`
2. Add router to `backend/app/main.py` if new file
3. Test at http://localhost:3101/docs

### Add New Frontend Page
1. Create `frontend/src/app/[page-name]/page.tsx`
2. Add link in `NavigationMenu.tsx`
3. Add feature card in `page.tsx` (home)

### Database Schema Changes
1. Update stored procedures in SQL Server
2. Update router function parameters
3. Update Pydantic models if needed
4. Update frontend TypeScript interfaces

### Debugging

#### Backend Debug
```python
# Add print statements (logs to console/file)
print(f"DEBUG: {variable}")

# Check FastAPI auto-docs
# Visit http://localhost:3101/docs
```

#### Frontend Debug
```typescript
// Console logging
console.log('Debug:', data);

// Network tab in browser DevTools
// Check request/response headers and payloads
```

#### Database Debug
```sql
-- Test stored procedure directly in SSMS
EXEC [Order].[usp_GetOrder] @pvchTradeAccountName = 'huanw2114'

-- Check table directly
SELECT TOP 10 * FROM [Order].[Order] ORDER BY CreateDate DESC
```

## File Structure Essentials

```
Key Files to Know:
├── backend/app/main.py                    # FastAPI entry point
├── backend/app/core/config.py             # Settings & env vars
├── backend/app/routers/[feature].py       # API endpoints
├── frontend/src/app/layout.tsx            # Root layout
├── frontend/src/app/page.tsx              # Home page
├── frontend/src/app/[feature]/page.tsx    # Feature pages
├── frontend/src/app/contexts/AuthContext.tsx  # Auth state
├── frontend/src/app/utils/authenticatedFetch.ts  # API helper
└── start-apps.ps1                         # Startup script
```

## Troubleshooting

### Port in Use
```powershell
# Stop all
.\stop-apps.ps1

# Or manually kill
Get-NetTCPConnection -LocalPort 3100 | % {Stop-Process -Id $_.OwningProcess -Force}
Get-NetTCPConnection -LocalPort 3101 | % {Stop-Process -Id $_.OwningProcess -Force}
```

### Can't Connect to Database
```powershell
# Check SQL Server is running
Get-Service | Where-Object {$_.Name -like "*SQL*"}

# Test connection
sqlcmd -S YOUR_SERVER -U YOUR_USER -P YOUR_PASSWORD -Q "SELECT @@VERSION"
```

### Frontend Build Issues
```bash
cd frontend
rm -rf .next node_modules
npm install
npm run dev
```

### Backend Issues
```bash
cd backend
# Deactivate and recreate venv if needed
rm -rf ../venv
python -m venv ../venv
..\venv\Scripts\activate
pip install -r requirements.txt
```

## Key Patterns

### Adding Basic Auth to Endpoint
```python
from app.routers.auth import verify_credentials
from fastapi import Depends

@router.get("/protected-endpoint")
def protected_route(username: str = Depends(verify_credentials)):
    # username contains the authenticated user
    return {"message": f"Hello {username}"}
```

### Frontend Authenticated API Call
```typescript
import { authenticatedFetch } from '../utils/authenticatedFetch';

const response = await authenticatedFetch(
  `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/endpoint`,
  { method: 'POST', body: JSON.stringify(data) }
);
```

### Database Query Pattern
```python
from app.core.db import get_sql_model

def get_data():
    try:
        model = get_sql_model()
        data = model.execute_read_query(
            "exec [Schema].[StoredProc] @param1 = ?, @param2 = ?",
            (value1, value2)
        )
        return data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

## Package Management

### Backend (Python)
```bash
# Add new package
pip install package-name
pip freeze > requirements.txt

# Update package
pip install --upgrade package-name
```

### Frontend (npm)
```bash
# Add new package
npm install package-name

# Update package
npm update package-name

# Check outdated
npm outdated
```

