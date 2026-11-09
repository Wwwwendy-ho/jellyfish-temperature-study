"""Session 1 test slice: download small samples and load into DuckDB. Download/load only."""
import requests, duckdb, pathlib, pandas as pd
ROOT = pathlib.Path(__file__).resolve().parents[1]; RAW = ROOT/"data"/"raw"; RAW.mkdir(parents=True, exist_ok=True)
NOAA = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
def noaa(station, b, e):
    r = requests.get(NOAA, params=dict(product="water_temperature", station=station, begin_date=b, end_date=e,
        units="metric", time_zone="gmt", format="json", interval="h"), timeout=60).json()
    df = pd.DataFrame(r["data"]).rename(columns={"t": "ts_utc", "v": "temp_c", "f": "flags"})
    df.insert(0, "station", station); return df
t = pd.concat([noaa("9447130", "20180701", "20180731"), noaa("9446484", "20180701", "20180731")])
t.to_csv(RAW/"noaa_test_201807.csv", index=False)
G = "https://api.gbif.org/v1/occurrence/search"
rows = []
for off in (0, 300):
    d = requests.get(G, params=dict(taxonKey=352, decimalLatitude="47.0,48.5", decimalLongitude="-123.2,-122.2",
        hasCoordinate="true", year="2023,2023", limit=300, offset=off), timeout=60).json(); rows += d["results"]
keep = ["key","scientificName","speciesKey","acceptedScientificName","eventDate","year","month","decimalLatitude","decimalLongitude","license","basisOfRecord","datasetKey","coordinateUncertaintyInMeters"]
g = pd.DataFrame(rows).reindex(columns=keep); g.to_csv(RAW/"gbif_test_scyphozoa_2023.csv", index=False)
con = duckdb.connect(str(ROOT/"data"/"jelly_test.duckdb"))
con.execute(f"CREATE OR REPLACE TABLE noaa_test AS SELECT * FROM read_csv_auto('{RAW/'noaa_test_201807.csv'}')")
con.execute(f"CREATE OR REPLACE TABLE gbif_test AS SELECT * FROM read_csv_auto('{RAW/'gbif_test_scyphozoa_2023.csv'}')")
for q in ["SELECT station, count(*) n, min(ts_utc) first, max(ts_utc) last, round(avg(temp_c),2) mean_c, count(*) FILTER (temp_c IS NULL) null_temp FROM noaa_test GROUP BY 1",
          "SELECT * FROM noaa_test LIMIT 5",
          "SELECT count(*) n, count(eventDate) has_date, count(decimalLatitude) has_coord FROM gbif_test",
          "SELECT license, count(*) FROM gbif_test GROUP BY 1",
          "SELECT species_name, count(*) FROM (SELECT coalesce(acceptedScientificName, scientificName) species_name FROM gbif_test) GROUP BY 1 ORDER BY 2 DESC LIMIT 5",
          "SELECT key, acceptedScientificName, eventDate, decimalLatitude, decimalLongitude, license FROM gbif_test LIMIT 5"]:
    print(">>", q[:70]); print(con.sql(q).df().to_string(index=False)); print()
