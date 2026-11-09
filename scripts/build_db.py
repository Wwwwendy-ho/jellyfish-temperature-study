"""Load raw NOAA CSVs into DuckDB (data/jelly.duckdb), then run sql/*.sql in filename order. Load + run only."""
import duckdb, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
con = duckdb.connect(str(ROOT/"data"/"jelly.duckdb"))
con.execute(f"""CREATE OR REPLACE TABLE raw_noaa_hourly AS
SELECT regexp_extract(filename, '(\\d{{7}})_\\d{{4}}\\.csv$', 1) AS station,
       "Date Time" AS ts_utc, "Water Temperature" AS temp_c, "X" AS flag_x, "N" AS flag_n, "R" AS flag_r,
       regexp_extract(filename, '[^/\\\\]+$') AS source_file
FROM read_csv('{ROOT.as_posix()}/data/raw/noaa/*.csv', header=true, filename=true)""")
print("raw_noaa_hourly rows:", con.execute("SELECT count(*) FROM raw_noaa_hourly").fetchone()[0])

GB = ROOT/"data"/"raw"/"gbif"
if (GB/"scyphozoa_2019_2025.csv").exists():
    con.execute(f"CREATE OR REPLACE TABLE raw_gbif_jelly AS SELECT * FROM read_csv('{(GB/'scyphozoa_2019_2025.csv').as_posix()}', header=true)")
    con.execute(f"CREATE OR REPLACE TABLE raw_gbif_comparison AS SELECT * FROM read_csv('{(GB/'comparison_monthly.csv').as_posix()}', header=true)")
    print("raw_gbif_jelly rows:", con.execute("SELECT count(*) FROM raw_gbif_jelly").fetchone()[0],
          "| raw_gbif_comparison rows:", con.execute("SELECT count(*) FROM raw_gbif_comparison").fetchone()[0])
for f in sorted((ROOT/"sql").glob("[0-9][0-9]_*.sql")):
    print("running", f.name); con.execute(f.read_text())
