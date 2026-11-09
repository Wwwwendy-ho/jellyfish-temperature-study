#!/usr/bin/env bash
# Rebuild: download NOAA data -> load into DuckDB -> run sql/*.sql. (Windows: port to run_all.ps1.)
set -euo pipefail
python3 scripts/01_download_noaa.py
python3 scripts/build_db.py
