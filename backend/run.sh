#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "$SCRIPT_DIR/../venv/bin/activate"
cd "$SCRIPT_DIR"
exec uvicorn app.main:app --reload --port 3101


