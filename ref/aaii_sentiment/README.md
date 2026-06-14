# AAII Sentiment Knowledge

This folder is a self-contained package for interpreting AAII sentiment using
historical S&P 500 forward performance.

## Contents

- `sentiment.xls`: source workbook.
- `model_aaii_spx.py`: prediction and interpretation model.
- `FINDINGS.md`: full human-readable findings and usage guidance.
- `aaii_sentiment_knowledge.json`: structured knowledge for other systems.
- `generate_findings.py`: regenerates both findings artifacts.
- `requirements.txt`: workbook-reading dependency.

## Refresh

After replacing `sentiment.xls` with a newer workbook:

```powershell
.\venv\Scripts\python.exe WebScraping\aaii_sentiment\generate_findings.py
```

Score an individual new reading:

```powershell
.\venv\Scripts\python.exe WebScraping\aaii_sentiment\model_aaii_spx.py `
  --bullish 30.4 --neutral 22.0 --bearish 47.6 --json
```

The model is intended as market context. Its held-out forecasting improvement
is weak, so it should not be used as a standalone trading signal.
