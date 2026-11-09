"""Download GBIF data to data/raw/gbif/: (1) Scyphozoa (jellyfish) records, (2) monthly counts for the comparison panel.
Box, years and dataset are fixed below. Observer names (recordedBy) are intentionally not kept. Download only."""
import requests, pandas as pd, pathlib, json, datetime as dt, time
ROOT = pathlib.Path(__file__).resolve().parents[1]; OUT = ROOT/"data"/"raw"/"gbif"; OUT.mkdir(parents=True, exist_ok=True)
S = "https://api.gbif.org/v1/occurrence/search"
INAT = "50c9509d-22c7-4a22-a47d-8c48425ef4a7"   # iNaturalist Research-grade Observations
BOX = {"decimalLatitude": "47.0,48.5", "decimalLongitude": "-123.2,-122.2", "hasCoordinate": "true",
       "datasetKey": INAT, "year": "2019,2025"}
PANEL = {"Echinodermata": 50, "Decapoda": 637, "Phocidae": 5310, "Otariidae": 5309, "Cetacea": 733}  # GBIF taxon keys (verified by name match)
KEEP = ["key", "scientificName", "acceptedScientificName", "taxonRank", "taxonomicStatus", "speciesKey", "species",
        "eventDate", "year", "month", "day", "decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters",
        "license", "basisOfRecord", "datasetKey", "issues"]
def get(params):
    for i in range(4):
        try:
            r = requests.get(S, params=params, timeout=90); r.raise_for_status(); return r.json()
        except Exception as e:
            if i == 3: raise
            time.sleep(2 ** (i + 1))
# 1. jellyfish records (class Scyphozoa, taxonKey 352)
rows, off = [], 0
while True:
    d = get(dict(BOX, taxonKey=352, limit=300, offset=off))
    rows += d["results"]; off += 300
    if d["endOfRecords"]: break
total = d["count"]
df = pd.DataFrame(rows).reindex(columns=KEEP); df["issues"] = df["issues"].apply(lambda x: ";".join(x) if isinstance(x, list) else x)
df.to_csv(OUT/"scyphozoa_2019_2025.csv", index=False)
# 2. comparison panel: record counts per group, year and month (facet on month, one request per group-year)
cm = []
for g, k in PANEL.items():
    for y in range(2019, 2026):
        d = get(dict(BOX, taxonKey=k, year=f"{y},{y}", limit=0, facet="month", facetLimit=12))
        got = {int(c["name"]): c["count"] for c in d["facets"][0]["counts"]}
        cm += [dict(group_name=g, taxon_key=k, year=y, month=m, n_records=got.get(m, 0)) for m in range(1, 13)]
pd.DataFrame(cm).to_csv(OUT/"comparison_monthly.csv", index=False)
# 3. Context only: jellyfish record counts per year before the study window (same box and dataset), written to outputs/.
d = get(dict(BOX, taxonKey=352, year="2010,2018", limit=0, facet="year", facetLimit=20))
pre = sorted((int(c["name"]), c["count"]) for c in d["facets"][0]["counts"])
pd.DataFrame(pre, columns=["year", "n_jellyfish_records"]).to_csv(ROOT/"outputs"/"gbif_jellyfish_counts_2010_2018.csv", index=False)
json.dump(dict(lookup_date=dt.date.today().isoformat(), api=S, filters=BOX, jellyfish_taxonKey=352, panel=PANEL,
               jellyfish_api_count=total, jellyfish_rows_downloaded=len(df)), open(OUT/"gbif_query_meta.json", "w"), indent=1)
print("jellyfish rows", len(df), "api count", total, "| comparison rows", len(cm))
