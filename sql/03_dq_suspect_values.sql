-- 03_dq_suspect_values.sql: unflagged temperatures outside 3-22 C. The thresholds are a plausibility
-- screen chosen for Puget Sound surface water, not a NOAA rule; rows are listed for review, not dropped.
CREATE OR REPLACE TABLE dq_noaa_suspect_values AS
SELECT station, ts_utc, temp_c FROM noaa_hourly
WHERE temp_c IS NOT NULL AND NOT is_flagged AND (temp_c < 3 OR temp_c > 22)
ORDER BY station, ts_utc;
COPY dq_noaa_suspect_values TO 'outputs/dq_noaa_suspect_values.csv' (HEADER);
