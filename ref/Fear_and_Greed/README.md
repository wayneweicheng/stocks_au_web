# CNN Fear & Greed Knowledge

This folder downloads CNN's historical Fear & Greed chart data, joins it to the
S&P 500 series supplied by the same endpoint, and creates reusable findings.

## Refresh everything

```powershell
.\venv\Scripts\python.exe WebScraping\Fear_and_Greed\download_history.py
.\venv\Scripts\python.exe WebScraping\Fear_and_Greed\generate_findings.py
```

## Score a new reading

```powershell
.\venv\Scripts\python.exe WebScraping\Fear_and_Greed\model_fear_greed_spx.py `
  --score 34 --json
```

## Outputs

- `fear_greed_spx_history.csv`: cleaned date, score, rating, and S&P 500 close.
- `cnn_fear_greed_raw.json`: unmodified CNN endpoint response.
- `FINDINGS.md`: human-readable research findings.
- `fear_greed_knowledge.json`: structured knowledge for other systems.

CNN includes 83 early observations fixed at exactly 50. The analysis excludes
90 pre-cutoff rows in total and begins on January 22, 2021. The raw download
retains all rows, and the findings should be treated cautiously.
