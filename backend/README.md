# Backend (FastAPI)

Dev server: http://localhost:3101

Run locally:

```
source ../venv/bin/activate
uvicorn app.main:app --reload --port 3101
```

From repo root (or anywhere):

```
./backend/run.sh
```

Env variables are loaded from `.env` in this directory. Template uses these keys:

```
sql_server_host
sql_server_port
sql_server_database
sql_server_user
sql_server_password
allowed_origins
```

Install deps from requirements (includes arkofdata-common):

```
source ../venv/bin/activate
pip install -r requirements.txt
```
