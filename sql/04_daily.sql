-- 04_daily.sql: daily mean water temperature per station.
-- Day = UTC date (assumption; water temperature changes slowly, so the local-date difference is small).
-- A day counts only if it has >= 20 valid (non-null) hourly readings.
CREATE OR REPLACE TABLE noaa_daily_all AS
SELECT station, CAST(ts_utc AS DATE) AS d,
       count(temp_c) AS n_valid_hours,
       avg(temp_c) AS mean_c
FROM noaa_hourly
GROUP BY station, CAST(ts_utc AS DATE);

CREATE OR REPLACE TABLE noaa_daily AS
SELECT station, d, n_valid_hours, mean_c,
       -- day-of-year on a 365-day basis: Feb 29 maps to Feb 28's value (59); later days of leap years shift down by 1
       CASE WHEN month(d) = 2 AND day(d) = 29 THEN 59
            WHEN month(d) >= 3 AND (year(d) % 4 = 0 AND (year(d) % 100 <> 0 OR year(d) % 400 = 0)) THEN dayofyear(d) - 1
            ELSE dayofyear(d) END AS doy
FROM noaa_daily_all
WHERE n_valid_hours >= 20
  -- drop each station's last calendar day: it can be a partial day (e.g. data ends 20:00 UTC) that still passes the hour rule
  AND d < (SELECT max(CAST(h.ts_utc AS DATE)) FROM noaa_hourly h WHERE h.station = noaa_daily_all.station);

-- Coverage: days dropped by the 20-hour rule, per station.
CREATE OR REPLACE TABLE dq_noaa_daily_coverage AS
SELECT a.station, count(*) AS days_total, count(*) FILTER (WHERE a.n_valid_hours >= 20) AS days_kept,
       count(*) FILTER (WHERE a.n_valid_hours < 20) AS days_dropped
FROM noaa_daily_all a GROUP BY a.station ORDER BY a.station;
COPY dq_noaa_daily_coverage TO 'outputs/dq_noaa_daily_coverage.csv' (HEADER);
