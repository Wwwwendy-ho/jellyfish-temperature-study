-- 02_calendar.sql: data-quality checks on NOAA hourly temperature (Q1).
-- Hourly calendar spine per station from its first to last observed hour; anti-join finds missing hours.
CREATE OR REPLACE TABLE noaa_spine AS
SELECT s.station, g.ts_utc
FROM (SELECT station, min(ts_utc) AS t0, max(ts_utc) AS t1 FROM noaa_hourly GROUP BY station) s,
     LATERAL (SELECT unnest(generate_series(s.t0, s.t1, INTERVAL 1 HOUR)) AS ts_utc) g;

CREATE OR REPLACE TABLE noaa_missing_hours AS
SELECT sp.station, sp.ts_utc
FROM noaa_spine sp
LEFT JOIN noaa_hourly h ON h.station = sp.station AND h.ts_utc = sp.ts_utc
WHERE h.ts_utc IS NULL;

-- One row per station-year: expected vs present hours, duplicates in raw, null values, flagged rows.
CREATE OR REPLACE TABLE dq_noaa_station_year AS
WITH expected AS (SELECT station, year(ts_utc) AS yr, count(*) AS spine_hours FROM noaa_spine GROUP BY ALL),
     missing  AS (SELECT station, year(ts_utc) AS yr, count(*) AS missing_hours FROM noaa_missing_hours GROUP BY ALL),
     dups     AS (SELECT station, year(ts_utc) AS yr, sum(c - 1) AS duplicate_rows
                  FROM (SELECT station, ts_utc, count(*) AS c FROM raw_noaa_hourly GROUP BY ALL HAVING count(*) > 1) GROUP BY ALL),
     quality  AS (SELECT station, year(ts_utc) AS yr, count(*) AS rows_kept,
                         count(*) FILTER (WHERE temp_c IS NULL) AS null_temp,
                         count(*) FILTER (WHERE is_flagged) AS flagged_rows
                  FROM noaa_hourly GROUP BY ALL)
SELECT e.station, e.yr, e.spine_hours,
       coalesce(m.missing_hours, 0) AS missing_hours,
       coalesce(d.duplicate_rows, 0) AS duplicate_rows,
       coalesce(q.null_temp, 0) AS null_temp,
       coalesce(q.flagged_rows, 0) AS flagged_rows
FROM expected e
LEFT JOIN missing m USING (station, yr) LEFT JOIN dups d USING (station, yr) LEFT JOIN quality q USING (station, yr)
ORDER BY e.station, e.yr;

COPY dq_noaa_station_year TO 'outputs/dq_noaa_station_year.csv' (HEADER);

-- Gaps as runs of consecutive missing hours (gaps-and-islands), longest first.
CREATE OR REPLACE TABLE dq_noaa_gaps AS
WITH numbered AS (
  SELECT station, ts_utc,
         ts_utc - INTERVAL 1 HOUR * (row_number() OVER (PARTITION BY station ORDER BY ts_utc)) AS grp
  FROM noaa_missing_hours)
SELECT station, min(ts_utc) AS gap_start, max(ts_utc) AS gap_end, count(*) AS hours_missing
FROM numbered GROUP BY station, grp
ORDER BY hours_missing DESC, station, gap_start;
COPY dq_noaa_gaps TO 'outputs/dq_noaa_gaps.csv' (HEADER);
