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
        if f.exists() and y < today.year: continue
        end = min(dt.date(y, 12, 31), today)
        p = dict(product="water_temperature", station=st, begin_date=f"{y}0101", end_date=end.strftime("%Y%m%d"),
                 units="metric", time_zone="gmt", format="csv", interval="h")
        r = requests.get(URL, params=p, timeout=120)
        if r.status_code != 200 or r.text.lstrip().startswith("Error") or "No data" in r.text[:200] or len(r.text) < 50:
            print(st, y, "no data"); f.unlink(missing_ok=True); continue
        f.write_text(r.text); print(st, y, len(r.text.splitlines()) - 1, "rows"); time.sleep(0.3)
