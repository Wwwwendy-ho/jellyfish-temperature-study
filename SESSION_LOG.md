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


## Session 2 (2026-11-09): NOAA download, load, data-quality SQL
Done: scripts/01_download_noaa.py (hourly, one CSV per station-year, 13 MB, git-ignored), scripts/build_db.py (load + run sql/), sql/01_clean.sql, 02_calendar.sql, 03_dq_suspect_values.sql, outputs/dq_noaa_*.csv, requirements.txt, run_all.sh.
Data: Tacoma 9446484 hourly 1996-01-01 to 2026-11-09 (269,819 rows); Seattle 9447130 1996-01-01 to 2019-01-02 (201,659 rows). Timestamps UTC. CSV columns: Date Time, Water Temperature, X, N, R (NOAA flags).
Checks (reconciled: raw rows = kept rows, 0 duplicates, both stations):
- Missing hours vs hourly spine: Tacoma 681 (678 are one gap 1996-12-03 19:00 to 1997-01-01 00:00; the rest are single hours), Seattle 8.
- Null temperature: Tacoma 12,445, Seattle 7,754. Every null row is NOAA-flagged and every flagged row is null (observation, not a documented rule).
- Tacoma 2019-2026 has no missing hours; nulls per year 74, 2, 20, 1, 2, 7, 9, 22 (2026 partial).
- Unflagged values outside 3-22 C (my plausibility screen): Seattle 4 (1996-10-13 reads -0.9 to -0.7; 2000-06-25 reads 0.0), Tacoma 3 (24.0 on 2005-07-05, 2.6 on 2008-01-22, 2.7 on 2009-03-27; full list in outputs/dq_noaa_suspect_values.csv). Not removed; decide in Session 3.
- Hand check: Tacoma 2021-07-15 in pandas vs DuckDB, n=24, mean 13.2042, match.
Caveats: 2026 is partial (last hour 2026-11-09 20:00 UTC); exclude the partial last day and decide whether to use 2026. DuckDB 2.0 note: relations no longer have fetchone(); use con.execute(...).fetchone().
Next (Session 3): daily aggregation with a minimum-hours rule, day-of-year climatology and 90th percentile (baseline period to be decided), heatwave detection (gaps-and-islands), then a short Opus review of the logic. Seattle vs Tacoma overlap check in 1996-2018 also pending.

## Session 3 (2026-11-09): daily table, climatology, heatwave detection
Files: sql/04_daily.sql, 05_climatology.sql, 06_heatwaves.sql, 07_station_overlap.sql; outputs/climatology_tacoma.csv, heatwave_events_tacoma.csv, heatwave_year_summary_tacoma.csv, station_overlap.csv, station_overlap_by_year.csv, station_stability_by_year.csv, dq_noaa_daily_coverage.csv. Also downloaded Port Townsend 9444900 and Friday Harbor 9449880 (1996-2026) as reference stations; they now appear in the dq_noaa_* tables too.
Method: daily mean on UTC date, >=20 valid hours, each station's last (possibly partial) day dropped; day-of-year on a 365-day basis; pooled +/-5-day window, mean and 90th percentile (quantile_cont), 31-day circular smoothing; hot day > p90; event = >=5 consecutive calendar days hot (gaps-and-islands, no gap bridging). Events credited to start year.
**Finding about the data (observation): Tacoma reads colder than expected in 2007-2017.** Seattle minus Tacoma annual mean difference is -0.15 to -0.01 C in 1996-2006, then 0.25 to 1.26 C in 2007-2017, and -0.19 in 2018 (station_overlap_by_year.csv). Against Port Townsend and Friday Harbor, Seattle stays roughly steady (0.70-1.99 across years) while Tacoma drops about 1.2-1.4 C around 2009-2012 and returns to its earlier offset by 2018 and stays there through 2025 (station_stability_by_year.csv). Cause unknown (sensor, siting, or real local conditions); not resolved. Seattle-Tacoma daily correlation overall 0.955 over 7,565 days.
Decision: primary baseline = Tacoma complete years 1998-2025 excluding 2007-2017 (label excl_2007_2017); sensitivity = 1998-2025 all (full_1998_2025). 1997 excluded (only 169 usable days).
Results (heatwave_events_tacoma.csv): primary 66 events, 683 heatwave days, longest 63 days; sensitivity 79 events, 871 days. Detected events include late 2014 through 2016 (2015: 94 heatwave days in 10 events; 2016: 33 in 5), consistent with the 2014-2016 "Blob" timing named in the project brief (external check, not verified against literature here). 2019-2025 primary heatwave days: 23, 6, 5, 0, 50, 113, 97 (2026 partial: 173). 2007-2017 results are not reliable for Tacoma because of the offset above (zero events 2007-2013 should not be read as no warm water).
Review: Opus subagent reviewed 04-07 read-only: no logic bug that changes results; day-of-year mapping, circular pooling, smoothing, gaps-and-islands and join cardinality verified by queries. Fixes applied: 1997 excluded, comment corrections, partial last day dropped, year-boundary credit documented. Open, uncertain: Port Townsend reads about 0.5 C warmer relative to Tacoma in 2026 (unexplained; one station changed); annual station comparison uses unequal day sets in incomplete years; no Seattle data after 2019-01-02, so Tacoma's return to normal rests on two reference stations in other water bodies.
Caveat for the study: a fixed 1998-2025 baseline with a warming trend flags later years more often (slope not computed in this run, so no figure stated). Heatwave counts for 2024-2026 are large (113, 97, 173) and should be read with that in mind.
Next (Session 4): load GBIF jellyfish records 2019-2025 (Scyphozoa in the box, keep BY-NC/BY/CC0 with licence column, record GBIF lookup date), data-quality checks on dates/coordinates, build comparison group of other marine observations, effort-corrected monthly shares. Comparison group size is a decision to raise first (all animal records in the box are about 14M for 2010-2024).

## Session 4 (2026-11-09): jellyfish records, comparison panel, effort-corrected monthly share
Files: scripts/02_download_gbif.py (jellyfish records + monthly panel counts via GBIF search/facets; observer names not stored), build_db.py now also loads GBIF tables; sql/08_gbif_clean.sql, 09_effort_monthly.sql; outputs/dq_gbif_jellyfish.csv, jellyfish_species_monthly.csv, effort_monthly.csv, effort_monthly_by_group.csv. Raw GBIF files are git-ignored (data/raw/gbif/, includes gbif_query_meta.json with lookup date 2026-11-09 and the exact filters).
Scope: GBIF occurrence search, iNaturalist research-grade dataset only (datasetKey 50c9509d-22c7-4a22-a47d-8c48425ef4a7), box lat 47.0-48.5 / lon -123.2 to -122.2, years 2019-2025. Jellyfish = class Scyphozoa (taxonKey 352). Panel chosen before looking at ratios (decision made with the user): Echinodermata, Decapoda, Phocidae, Otariidae, Cetacea.
Data quality (dq_gbif_jellyfish.csv): 2,577 rows, 0 duplicate keys, 0 missing/invalid dates, 0 missing coordinates, 0 dropped from analysis. Coordinate uncertainty missing on 307 rows and over 5,000 m on 163 (kept; 5,000 m is my screen). 1 record not identified to species. Licences: CC BY-NC 2,339, CC BY 169, CC0 69. Species: Phacellophora camtschatica 1,473; Cyanea ferruginea 952; Aurelia labiata 143; Chrysaora fuscescens 8; unresolved 1.
Reconciliation: jellyfish rows equal the GBIF API count (2,577); jellyfish by year 140, 172, 352, 250, 505, 596, 562 match the earlier facet counts; panel group totals (Echinodermata 14,251; Decapoda 14,206; Phocidae 2,511; Otariidae 831; Cetacea 954; panel 32,753) match the earlier probe. Hand check Oct 2023 in pandas: jellyfish 34, panel 177; SQL gives the same, share 0.1611.
Observations (effort_monthly.csv; share = jellyfish / (jellyfish + panel)): yearly share 2019-2025 = 0.1007, 0.0943, 0.1080, 0.0695, 0.0921, 0.0706, 0.0496, while raw jellyfish counts rose 140 to 562 and the panel rose 1,250 to 10,775. 7 of 84 months have zero jellyfish records. Seasonal pattern pooled over years: share about 0.7-3% in Dec-May and about 10-13% in Jun-Oct. These are descriptive; no heatwave comparison yet.
Limits to carry into the README: iNaturalist only (other GBIF datasets excluded); counts of records, not of distinct observers; panel groups have their own seasonality and responses; jellyfish are recorded only when people look at the water, so absence in a month is not zero jellyfish. GBIF search results have no download DOI; a formal citation would need a GBIF download (decide before publishing).
Next (Session 5): heatwave vs normal comparison (sighting shares and first-sighting date by year) and species/month rankings; join effort_monthly to heatwave days per month; use the primary baseline, and treat 2019-2025 only. Note first-sighting dates depend on effort, so also report the panel's first record per year.

## Session 5 (2026-11-09): heatwave vs normal, rankings, year view
Files: sql/10_monthly_heatwave.sql, 11_year_comparison.sql; outputs/monthly_heatwave_effort.csv, heatwave_vs_normal_summary.csv, heatwave_vs_normal_by_year.csv, species_shift_ranking.csv, month_shift_ranking.csv, year_comparison.csv, year_group_summary.csv.
Decisions fixed BEFORE looking at jellyfish ratios: heatwave month = >=5 heatwave days (primary-baseline events, counted by actual date); main season Jun-Oct; share anomaly adjusted for calendar-month mean and then year mean (within-year contrast; removes the post-2022 rise in effort and heatwave days); sensitivities: all months, >=10 days, >=1 day. Year-level heatwave year = >=10 heatwave days in Jun-Oct (2023, 2025); year view is descriptive only. Note: heatwave days by date (294 in 2019-2025, reconciled to the monthly table) differ slightly from the per-year summary, which credits events to their start year (e.g. 2023: 39 vs 50).
Checks: 294 heatwave days = monthly sum; hand check of 2025-06 adjusted anomaly (+0.0295) and June calendar mean (0.1043) in pandas.
Results (all descriptive; heatwave_vs_normal_summary.csv):
- Primary (Jun-Oct, >=5 days): 7 heatwave months vs 28 normal, 5 informative years. Raw mean share 0.1139 vs 0.1321; adjusted difference -0.0053 (heatwave minus normal). Sensitivities: -0.0083 (>=10 days, only 3 heatwave months, 2 informative years), -0.0108 (>=1 day, 8 months), -0.0008 (all months, 22 heatwave months).
- Per-year adjusted difference (heatwave_vs_normal_by_year.csv): 2019 -0.0722, 2021 -0.0204, 2023 +0.0032, 2024 +0.0471, 2025 +0.0035 (each year has 1 heatwave month except 2025 with 3). Signs are mixed (2 negative, 3 positive).
- Species ranking (relative shift in heatwave months, 23-397 records in those months): Aurelia labiata +0.083, Phacellophora camtschatica +0.034, Cyanea ferruginea -0.105, other n/a. Differences are tiny and rest on few months.
- Month ranking: Aug largest absolute shift (-0.0674) but based on 1 heatwave year; no month has more than 2 heatwave years.
- Year view (year_comparison.csv): Jun-Oct share 2019-2025 = 0.1259, 0.1489, 0.1828, 0.0858, 0.1334, 0.0958, 0.0831. Heatwave years (2023, 2025) vs others: mean Jun-Oct share 0.1082 vs 0.1278; mean first-sighting day-of-year from 1 Apr 109 vs 115; mean 10th-record day-of-year from 1 Apr 138 vs 147. First sighting any date is Jan 1-15 every year (jellyfish are recorded year-round), so the from-April metrics are used. Panel records Apr-Jun rose from 429 (2019) to 4,713 (2025); the earliest from-April first sightings were 2022-04-07 (zero heatwave days), 2025-04-09, 2024-04-14.
Reading (what the data support): no consistent association between heatwave months and effort-corrected jellyfish share. The estimate is slightly negative in the primary spec, the sign flips across years, and the design has little power (7 heatwave months in the main season, 5 informative years; heatwave exposure falls mostly outside Jun-Oct, e.g. Jan-Apr 2024 and Oct-Dec 2023/2025). This is not evidence of no effect. First-sighting timing tracks observer effort at least as plausibly as heat. No significance tests were run (months within a year are not independent).
Not done: lagged heatwave effects (e.g. a heatwave a month earlier) and a permutation test; list as next steps. Q7 validation (heatwaves vs the 2014-2016 Blob) is covered by the Session 3 event list; jellyfish cannot be tested for 2014-2016 (too few records before 2019).
Next (Session 6): charts (matplotlib) and README draft; Session 7 numbers audit. Windows run_all.ps1 still to be written/ported.
