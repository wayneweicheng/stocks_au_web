# Coding Conventions & Best Practices

## General Principles

1. **Never use fallback data** - Always use real data from the database. If data retrieval fails, log the error and move to the next/previous trading day.
2. **Prefer stored procedures** - Use existing stored procedures rather than raw SQL queries
3. **Maintain consistency** - Follow existing patterns in the codebase
4. **Type safety** - Use TypeScript interfaces on frontend, Pydantic models on backend

## Backend (Python/FastAPI)

### File Organization
```
backend/app/
├── main.py              # FastAPI app, CORS, router includes
├── core/
│   ├── config.py        # Pydantic settings
│   └── db.py            # Database utilities
└── routers/
    ├── auth.py          # No /api prefix, uses /auth
    └── [feature].py     # All use /api prefix
```

### Router Structure
```python
from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials

router = APIRouter(prefix="/api", tags=["feature-name"])

@router.get("/endpoint")
def get_endpoint(
    param: str = Query(..., description="Parameter description"),
    username: str = Depends(verify_credentials)  # If auth needed
) -> List[Dict[str, Any]]:
    """Endpoint documentation"""
    try:
        model = get_sql_model()
        data = model.execute_read_query(
            "exec [Schema].[usp_StoredProc] @param1 = ?",
            (param,)
        )
        return data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

### Database Patterns

**Reading Data**:
```python
# For SELECT queries
model = get_sql_model()
data = model.execute_read_query(sql, params)
# or
data = model.execute_read_usp(sql, params)
```

**Writing Data**:
```python
# For INSERT/UPDATE/DELETE - ensures commit
model = get_sql_model()
model.execute_update_usp(sql, params)
```

**Different Database**:
```python
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

model = SQLServerModel(database='StockDB')
model.execute_read_usp(sql, params)
```

**Stored Procedure with Output Parameters**:
```python
# Wrap with DECLARE to handle output params
model.execute_update_usp(
    """
    DECLARE @pintErrorNumber INT = 0, @pvchMessage VARCHAR(200);
    EXEC [Schema].[usp_Procedure]
        @param1 = ?,
        @param2 = ?,
        @pintErrorNumber = @pintErrorNumber OUTPUT,
        @pvchMessage = @pvchMessage OUTPUT;
    """,
    (value1, value2)
)
```

### Data Transformation
```python
# Database fields are PascalCase, API should be snake_case
def transform_data(records):
    transformed = []
    for record in records:
        transformed.append({
            'field_name': record.get('FieldName'),
            'other_field': record.get('OtherField'),
        })
    return transformed

@router.get("/endpoint")
def get_data():
    data = model.execute_read_usp(sql, params)
    if data:
        return transform_data(data)
    return []
```

### Date Handling
```python
# Convert frontend date (YYYY-MM-DD) to SQL Server format (YYYYMMDD)
date_formatted = None
if date_string:
    # Handle ISO datetime format too (YYYY-MM-DDTHH:MM:SS)
    date_part = date_string.split('T')[0]
    date_formatted = date_part.replace('-', '')
```

### Error Handling
```python
# Option 1: Return empty data
try:
    data = model.execute_read_query(sql, params)
    return data or []
except Exception as e:
    return []

# Option 2: Return error message in response
try:
    data = model.execute_read_query(sql, params)
    return data or []
except Exception as e:
    return {"message": f"Error: {str(e)}"}

# Option 3: Raise HTTP exception (for critical errors)
try:
    data = model.execute_read_query(sql, params)
    return data or []
except Exception as e:
    raise HTTPException(status_code=500, detail=str(e))
```

### Pydantic Models
```python
from pydantic import BaseModel
from typing import Optional

class OrderModel(BaseModel):
    id: Optional[int] = None
    stock_code: str
    order_price: Optional[float] = None
    order_volume: Optional[int] = None
```

### Debug Logging
```python
# Use print statements (output goes to logs)
print(f"DEBUG - Function called with params: {params}")
print(f"DEBUG - Query result: {data}")
```

## Frontend (Next.js/React/TypeScript)

### File Organization
```
frontend/src/app/
├── layout.tsx           # Root layout
├── page.tsx            # Home page
├── globals.css         # Global styles
├── contexts/
│   └── AuthContext.tsx
├── components/
│   ├── AuthWrapper.tsx
│   └── [Component].tsx
├── utils/
│   └── authenticatedFetch.ts
└── [feature]/
    └── page.tsx
```

### Page Structure
```typescript
"use client";

import { useEffect, useState } from "react";

interface DataType {
  id: number;
  field_name: string;
  other_field?: string;
}

export default function FeaturePage() {
  const [data, setData] = useState<DataType[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");
  const [message, setMessage] = useState<string>("");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${baseUrl}/api/endpoint`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const result = await response.json();
      setData(result);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6">
          Feature Title
        </h1>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        {message && (
          <div className="mb-4 rounded-md border border-green-200 bg-green-50 text-green-700 px-3 py-2 text-sm">
            {message}
          </div>
        )}

        {/* Content */}
      </div>
    </div>
  );
}
```

### API Calls

**Public Endpoint**:
```typescript
const response = await fetch(`${process.env.NEXT_PUBLIC_BACKEND_URL}/api/endpoint`);
if (!response.ok) throw new Error(`HTTP ${response.status}`);
const data = await response.json();
```

**Protected Endpoint**:
```typescript
import { authenticatedFetch } from '../utils/authenticatedFetch';

const response = await authenticatedFetch(
  `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/endpoint`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  }
);
if (!response.ok) throw new Error(`HTTP ${response.status}`);
const data = await response.json();
```

### Form Handling
```typescript
const [formData, setFormData] = useState<FormType>({
  field1: "",
  field2: 0,
});

const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault();
  setError("");
  setMessage("");
  
  try {
    const response = await fetch(`${baseUrl}/api/endpoint`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(formData),
    });
    
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    
    const result = await response.json();
    setMessage(result.message);
    
    // Reset form
    setFormData({ field1: "", field2: 0 });
    loadData(); // Refresh data
  } catch (e: unknown) {
    setError(e instanceof Error ? e.message : 'Unknown error');
  }
};
```

### TypeScript Interfaces
```typescript
// Match backend response structure (snake_case)
interface Order {
  id?: number;
  stock_code: string;
  order_type: string;
  order_price?: number;
  created_date?: string;
}

// Use Optional<?> for nullable fields
// Use undefined for optional fields
```

### Date Handling
```typescript
// Display date from ISO string
{order.created_date ? new Date(order.created_date).toLocaleDateString() : "-"}

// Date input default value
const getDefaultDate = () => {
  const date = new Date();
  date.setDate(date.getDate() + 60);
  return date.toISOString().slice(0, 10); // YYYY-MM-DD
};
```

### Conditional Rendering
```typescript
{loading && (
  <div className="flex items-center justify-center">
    <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
  </div>
)}

{error && <div className="text-red-600">Error: {error}</div>}

{data.length === 0 ? (
  <div className="text-center text-slate-500">No data found.</div>
) : (
  <table>...</table>
)}
```

## CSS/Styling (Tailwind)

### Color Scheme
- Primary gradient: `from-emerald-600 to-green-600`
- Secondary gradient: `from-blue-500 to-indigo-600`
- Background: `bg-gradient-to-b from-emerald-50 via-white to-white`
- Text: `text-slate-800`, `text-slate-600` (secondary)

### Common Classes
```html
<!-- Container -->
<div className="mx-auto max-w-7xl px-6 py-10">

<!-- Card -->
<div className="rounded-lg border border-slate-200 bg-white p-6">

<!-- Button Primary -->
<button className="rounded-md bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-400/40">

<!-- Input -->
<input className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40" />

<!-- Gradient Text -->
<h1 className="bg-gradient-to-r from-emerald-600 to-green-600 bg-clip-text text-transparent">
```

## Testing & Debugging

### Backend Testing
1. Use FastAPI auto-docs: http://localhost:3101/docs
2. Test stored procedures directly in SSMS first
3. Add print statements for debugging
4. Check logs in `logs/backend-*.log`

### Frontend Testing
1. Use browser DevTools Network tab
2. Check console for errors
3. Inspect sessionStorage for auth data
4. Use React DevTools for component state

### Database Testing
```sql
-- Test stored procedure
EXEC [Schema].[usp_Procedure] @param1 = 'value1', @param2 = 'value2'

-- Check results directly
SELECT * FROM [Schema].[Table] WHERE condition

-- Check recent inserts
SELECT TOP 10 * FROM [Schema].[Table] ORDER BY CreateDate DESC
```

## Git Workflow

### Ignored Files
- `logs/` - Runtime logs
- `venv/` - Python virtual environment
- `node_modules/` - npm packages
- `.env` - Environment variables
- `*.log` - Log files
- `.next/` - Next.js build output

### Before Committing
1. Test locally with `.\start-apps.ps1`
2. Check linter: `npm run lint` (frontend)
3. Verify no sensitive data in commits
4. Don't commit `.env` files

## Performance Considerations

### Backend
- Use stored procedures (they're optimized)
- Return only needed columns
- Use pagination for large datasets
- Cache frequently accessed data if needed

### Frontend
- Minimize re-renders with proper state management
- Use `useEffect` dependencies correctly
- Debounce search inputs
- Show loading states for better UX

## Security Best Practices

1. **Never log passwords or sensitive data**
2. **Use Basic Auth headers** (already implemented)
3. **Validate all inputs** on backend
4. **Use parameterized queries** (already done via stored procedures)
5. **Don't expose error details** to frontend (except in dev)
6. **Keep dependencies updated**

## Naming Conventions

### Backend
- Files: `snake_case.py`
- Functions: `snake_case()`
- Classes: `PascalCase`
- Constants: `UPPER_CASE`
- Database fields in code: `snake_case`

### Frontend
- Files: `PascalCase.tsx` (components), `camelCase.ts` (utilities)
- Components: `PascalCase`
- Functions: `camelCase()`
- Interfaces: `PascalCase`
- CSS classes: Tailwind utilities

### Database
- Schemas: `[PascalCase]`
- Tables: `PascalCase`
- Stored Procedures: `usp_PascalCase`
- Parameters: `@pvchParameterName` (type prefix + PascalCase)
- Columns: `PascalCase`

## Common Mistakes to Avoid

1. **Don't use raw SQL** - Use stored procedures
2. **Don't forget error handling** - Always wrap in try-catch
3. **Don't hardcode URLs** - Use environment variables
4. **Don't mix databases** - Know which database each endpoint uses
5. **Don't forget to commit** - Use `execute_update_usp` for writes
6. **Don't skip loading states** - Always show user feedback
7. **Don't forget CORS** - Backend must allow frontend origin
8. **Don't use fallback data** - Always use real data or fail gracefully

