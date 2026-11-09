-- 01_clean.sql: hourly NOAA water temperature, one row per (station, ts_utc).
-- Raw timestamps are GMT/UTC (requested time_zone=gmt). X/N/R are NOAA quality flags
-- (max exceeded / min exceeded / rate of change exceeded); a row is flagged if any is 1.
CREATE OR REPLACE TABLE noaa_hourly AS
SELECT station, ts_utc, temp_c,
       (coalesce(flag_x,0) + coalesce(flag_n,0) + coalesce(flag_r,0)) > 0 AS is_flagged,
       source_file
FROM raw_noaa_hourly
QUALIFY row_number() OVER (PARTITION BY station, ts_utc ORDER BY source_file DESC) = 1;
