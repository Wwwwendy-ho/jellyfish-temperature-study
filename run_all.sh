#!/usr/bin/env bash
# Rebuild everything: download -> load into DuckDB -> run sql/*.sql -> draw charts. (Windows: run_all.ps1)
set -euo pipefail
python3 -m pip install -r requirements.txt
python3 scripts/01_download_noaa.py
python3 scripts/02_download_gbif.py
python3 scripts/build_db.py
python3 scripts/03_charts.py
