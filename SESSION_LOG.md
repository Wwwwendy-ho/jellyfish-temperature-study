# Session log

## Session 1 (2026-11-09): verification and test slice
Environment: Linux cloud container (not the Windows PC), repo at /home/user/jellyfish-sql. Python 3.13, pandas 3.0.5, DuckDB 2.0.0 (pip-installed this session).
Network: NOAA and GBIF hosts were blocked by the container policy; api.tidesandcurrents.noaa.gov and api.gbif.org were added to the Default environment allowlist (user-approved prompt).

### NOAA CO-OPS (product water_temperature, interval=h available, units metric, GMT)
- Station 9447130 Seattle: id/name/coords verified (47.6026, -122.3393). Data exist 1995 (1990 empty); **ends in 2018**: every probed day in 2018 has 24 hourly rows, every probed day in 2019+ has none. Exact last date not pinned (probed the 15th of each month only).
- Same product at other stations (probed one day, 15 Jul, in selected years): Tacoma 9446484, Friday Harbor 9449880, Port Angeles 9444090 have data 1998-2025; Port Townsend 9444900 to 2024 (partial 2025); Cherry Point 9449424 stops before 2014; Bremerton 9445958 none. Probe is one day per year, not a coverage audit.
- Test slice Jul 2018: Seattle 744 hourly rows (1 null), Tacoma 744 (4 null); monthly means 12.87 / 12.77 C.

### GBIF (box lat 47.0-48.5, lon -123.2 to -122.2, hasCoordinate; my rough Puget Sound box, an assumption)
- Class Scyphozoa (taxonKey 352): 3,882 records in box. Species counts: Phacellophora camtschatica 2,463; Cyanea ferruginea 1,110; Aurelia labiata 207; Chrysaora fuscescens 9; Chrysaora colorata 1; **Cyanea capillata 3**.
- 3,765 of 3,882 come from the iNaturalist Research-grade dataset (50c9509d...). Records are sparse before 2019: for Scyphozoa in that dataset, 2014: 14, 2015: 17, 2016: 24, 2017: 40, 2018: 86, 2019: 140, 2023: 505, 2024: 596, 2026 (partial): 972.
- Licences (Scyphozoa, iNat dataset): CC_BY_NC 3,439; CC_BY 212; CC0 114. **About 91% are non-commercial (BY-NC), which the brief's CC0/CC-BY filter would drop.**
- Test slice: all 2023 Scyphozoa in box = 505 rows (matches facet count); all have date and coordinates.
- Species-name matching: "Cyanea" and "Chrysaora" genus-level matches returned higher ranks (Cnidaria, Animalia); disregard those probe lines. Lion's mane in this area is recorded as Cyanea ferruginea, not C. capillata. Taxonomy as of GBIF lookup on 2026-11-09.

### Implications
1. Seattle temperature ends 2018, so it cannot cover recent years of sightings. Tacoma (or Friday Harbor) is needed for a temperature series to 2025.
2. Sightings before ~2018 are very few, so the 2014-2016 Blob cannot be tested with jellyfish records; only the temperature side can be validated against it.
3. Licence rule decision needed (BY-NC vs CC0/CC-BY only).

### Files
scripts/00_test_slice.py (download + load test slice), data/raw/*.csv and data/jelly_test.duckdb (git-ignored). Not yet committed.

### Decisions (user, 2026-11-09)
- Licence: CC BY-NC is acceptable (public non-commercial repo); keep licence column, cite datasets.
- Temperature: Tacoma 9446484 is the main series; Seattle 9447130 (to 2018) is a cross-check only.
- Sightings window: 2019-2025.
- GitHub: no remote created; user creates the repo and pushes.

### Next (Session 2)
Cleaning and data-quality SQL: calendar spine, missing/duplicate temperature hours/days for Tacoma, GBIF null-date/coordinate checks. Full Tacoma download first (ask before large download).
