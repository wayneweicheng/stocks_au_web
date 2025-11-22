Stock Research Reports (local-only)
===================================

This page lives at `/research-reports` in the Next.js app.

What it does
------------
- Add a stock code (e.g., `LLM.IN`) and a research report URL
- Stores entries in browser localStorage
- Search by stock code
- List is sorted by date added (newest first)
- Pagination (10 per page)
- Links open in a new tab

How to use
----------
1. Start the frontend (or open your deployed site)
2. Navigate to `Research Reports` from the header menu, or the card on the home page
3. Enter a stock code and a valid `http(s)` URL, then click `Add`
4. Use the search box to filter by stock code
5. Click a link to open the report in a new tab

Notes and limitations
---------------------
- Data is saved only in the browser that added it (localStorage). Clearing site data or switching devices will lose entries.
- To make this multi-device and multi-user, we can add simple backend APIs and store to a database.

Potential next features
-----------------------
- Backend persistence (FastAPI endpoint + DB)
- Edit and delete entries
- CSV/JSON export and import
- De-duplicate by (stock, url)
- Optional tags or notes per entry
- Metadata fetch (title/preview of URL)


