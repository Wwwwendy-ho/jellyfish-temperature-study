-- 06_heatwaves.sql: marine heatwave detection for Tacoma (9446484), once per baseline label.
-- A hot day = daily mean above that day-of-year's 90th-percentile threshold.
-- An event = >= 5 consecutive calendar days that are all hot (no gap-bridging; a missing day ends a run).
CREATE OR REPLACE TABLE tacoma_daily_anom AS
SELECT c.baseline, n.d, n.mean_c, c.clim_mean_c, c.p90_c, n.mean_c - c.clim_mean_c AS anomaly_c,
       n.mean_c > c.p90_c AS is_hot
FROM noaa_daily n JOIN climatology c USING (doy)
WHERE n.station = '9446484';

-- Gaps-and-islands: among hot days only, (date - row_number) is constant within a run of consecutive dates.
CREATE OR REPLACE TABLE heatwave_events AS
WITH hot AS (
  SELECT baseline, d, anomaly_c, mean_c,
         d - CAST(row_number() OVER (PARTITION BY baseline ORDER BY d) AS INTEGER) AS grp
  FROM tacoma_daily_anom WHERE is_hot),
runs AS (
  SELECT baseline, min(d) AS start_date, max(d) AS end_date, count(*) AS duration_days,
         round(avg(anomaly_c), 2) AS mean_anomaly_c, round(max(anomaly_c), 2) AS max_anomaly_c,
         round(max(mean_c), 2) AS peak_temp_c
  FROM hot GROUP BY baseline, grp)
SELECT baseline, row_number() OVER (PARTITION BY baseline ORDER BY start_date) AS event_id, * EXCLUDE (baseline)
FROM runs WHERE duration_days >= 5 ORDER BY baseline, start_date;
COPY heatwave_events TO 'outputs/heatwave_events_tacoma.csv' (HEADER);

-- Per-year summary. An event is credited to its START year, so heatwave_days for a year can include days that fall in the next year. Days = days kept by the 20-hour rule (2026 is partial, through 2026-11-09).
-- Years 2007-2017 are flagged: Tacoma data in those years look cold-biased relative to other stations.
CREATE OR REPLACE TABLE heatwave_year_summary AS
WITH days AS (
  SELECT a.baseline, year(a.d) AS yr, count(*) AS days_observed, count(*) FILTER (WHERE a.is_hot) AS hot_days,
         round(avg(a.anomaly_c), 2) AS mean_anomaly_c
  FROM tacoma_daily_anom a GROUP BY 1, 2),
ev AS (
  SELECT h.baseline, year(h.start_date) AS yr, count(*) AS n_events, sum(h.duration_days) AS heatwave_days
  FROM heatwave_events h GROUP BY 1, 2)
SELECT d.baseline, d.yr, d.days_observed, d.hot_days, coalesce(e.n_events, 0) AS n_events,
       coalesce(e.heatwave_days, 0) AS heatwave_days, d.mean_anomaly_c,
       d.yr BETWEEN 2007 AND 2017 AS tacoma_offset_period
FROM days d LEFT JOIN ev e USING (baseline, yr) ORDER BY d.baseline, d.yr;
COPY heatwave_year_summary TO 'outputs/heatwave_year_summary_tacoma.csv' (HEADER);
