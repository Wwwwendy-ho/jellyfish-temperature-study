"""Check that a GBIF Simple-CSV download holds the same records as the analysis data.
Usage: python scripts/verify_gbif_download.py path/to/<download-key>.csv
Compares record IDs only (no observer names are read or printed). Needs data/raw/gbif/scyphozoa_2019_2025.csv from 02_download_gbif.py."""
import csv, sys, pathlib
csv.field_size_limit(10**9)
ROOT = pathlib.Path(__file__).resolve().parents[1]
dl = {r["gbifID"] for r in csv.DictReader(open(sys.argv[1], encoding="utf-8", newline=""), delimiter="\t", quoting=csv.QUOTE_NONE)}
mine = {r["key"] for r in csv.DictReader(open(ROOT / "data/raw/gbif/scyphozoa_2019_2025.csv", encoding="utf-8"))}
print(f"download: {len(dl)} | analysis data: {len(mine)} | in both: {len(dl & mine)} | only download: {len(dl - mine)} | only analysis: {len(mine - dl)}")
sys.exit(0 if dl == mine else 1)
