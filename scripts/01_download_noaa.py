"""Download hourly NOAA CO-OPS water temperature, one CSV per station-year, to data/raw/noaa/.
Idempotent: skips completed past years; always refetches the current year. Download only."""
import requests, pathlib, datetime as dt, sys, time
ROOT = pathlib.Path(__file__).resolve().parents[1]; OUT = ROOT/"data"/"raw"/"noaa"; OUT.mkdir(parents=True, exist_ok=True)
URL = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
STATIONS = {"9446484": range(1996, 2027), "9447130": range(1996, 2020),  # Tacoma main; Seattle cross-check (ends 2018)
            "9444900": range(1996, 2027), "9449880": range(1996, 2027)}  # Port Townsend, Friday Harbor: tie-break checks
today = dt.date.today()
for st, years in STATIONS.items():
    for y in years:
        f = OUT/f"{st}_{y}.csv"
        if f.exists() and y < today.year - 1: continue          # past, complete years are kept; current and previous year are refetched
        end = min(dt.date(y, 12, 31), today)
        p = dict(product="water_temperature", station=st, begin_date=f"{y}0101", end_date=end.strftime("%Y%m%d"),
                 units="metric", time_zone="gmt", format="csv", interval="h")
        r = requests.get(URL, params=p, timeout=120)
        r.raise_for_status()                                      # any HTTP error stops the run instead of silently shrinking the data
        text = r.text
        if text.lstrip().startswith("Error"):
            if "No data was found" in text:                       # a genuinely empty station-year (e.g. before the record starts)
                print(st, y, "no data"); f.unlink(missing_ok=True); continue
            raise RuntimeError(f"NOAA error for {st} {y}: {text[:200]}")
        f.write_text(text); print(st, y, len(text.splitlines()) - 1, "rows"); time.sleep(0.3)
