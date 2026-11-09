# Rebuild everything: download -> load into DuckDB -> run sql/*.sql -> draw charts.
# Run from the repo root in PowerShell:  .\run_all.ps1
$ErrorActionPreference = "Stop"
python -m pip install -r requirements.txt
python scripts/01_download_noaa.py   # NOAA CO-OPS hourly water temperature (about 27 MB)
python scripts/02_download_gbif.py   # GBIF jellyfish records + comparison-panel counts (about 1 MB)
python scripts/build_db.py           # loads data/raw into data/jelly.duckdb and runs sql/01..11 in order
python scripts/03_charts.py          # writes outputs/charts/*.png
