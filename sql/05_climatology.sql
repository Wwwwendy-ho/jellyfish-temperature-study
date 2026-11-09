-- 05_climatology.sql: day-of-year climatology and 90th-percentile threshold for Tacoma (9446484).
-- Method (after Hobday et al. 2016, simplified): for each day of year, pool all baseline daily means within
-- +/-5 days (circular), take the mean and the 90th percentile, then smooth both with a 31-day circular moving average.
-- Two baselines, carried as a label through the pipeline:
--   'excl_2007_2017' (PRIMARY): complete years 1998-2025 minus 2007-2017, when Tacoma read colder than Seattle
--                    (0.25-1.26 C by year) and than two reference stations (see 07_station_overlap.sql). Cause unknown.
--   'full_1998_2025' (sensitivity): all complete years 1998-2025.
-- 1997 is excluded: Tacoma has only 169 usable days in 1997 (Jul-Dec), which would over-weight late-year days.
CREATE OR REPLACE TABLE baseline_spec AS
SELECT 'excl_2007_2017' AS baseline, yr FROM range(1998, 2026) t(yr) WHERE yr NOT BETWEEN 2007 AND 2017
UNION ALL
SELECT 'full_1998_2025', yr FROM range(1998, 2026) t(yr);

CREATE OR REPLACE TABLE baseline_daily AS
SELECT s.baseline, n.d, n.doy, n.mean_c
FROM noaa_daily n JOIN baseline_spec s ON s.yr = year(n.d)
WHERE n.station = '9446484';

-- Circular +/-5-day pooling: each observation is copied to the 11 day-of-year keys it contributes to.
CREATE OR REPLACE TABLE clim_raw AS
WITH offs AS (SELECT unnest(range(-5, 6)) AS off),
pooled AS (
  SELECT b.baseline, ((b.doy - 1 + o.off) % 365 + 365) % 365 + 1 AS doy, b.mean_c
  FROM baseline_daily b CROSS JOIN offs o)
SELECT baseline, doy, count(*) AS n_pooled, avg(mean_c) AS mean_raw, quantile_cont(mean_c, 0.9) AS p90_raw
FROM pooled GROUP BY baseline, doy;

-- 31-day circular smoothing: triple the 365 rows (-365, 0, +365) so the window wraps, then take a centered frame.
CREATE OR REPLACE TABLE climatology AS
WITH ext AS (
  SELECT baseline, doy + k AS pos, mean_raw, p90_raw FROM clim_raw CROSS JOIN (SELECT unnest([-365, 0, 365]) AS k) ks),
sm AS (
  SELECT baseline, pos, avg(mean_raw) OVER w AS clim_mean_c, avg(p90_raw) OVER w AS p90_c
  FROM ext WINDOW w AS (PARTITION BY baseline ORDER BY pos ROWS BETWEEN 15 PRECEDING AND 15 FOLLOWING))
SELECT baseline, pos AS doy, round(clim_mean_c, 3) AS clim_mean_c, round(p90_c, 3) AS p90_c
FROM sm WHERE pos BETWEEN 1 AND 365 ORDER BY baseline, pos;
COPY climatology TO 'outputs/climatology_tacoma.csv' (HEADER);
