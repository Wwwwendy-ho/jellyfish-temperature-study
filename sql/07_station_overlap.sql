-- 07_station_overlap.sql: Seattle (9447130) vs Tacoma (9446484) daily means over the overlap period.
-- Cross-check only: do the two stations move together? Reports n, correlation, mean and spread of difference.
CREATE OR REPLACE TABLE station_overlap AS
SELECT count(*) AS n_days, min(s.d) AS first_day, max(s.d) AS last_day,
       round(corr(s.mean_c, t.mean_c), 4) AS corr_daily_mean,
       round(avg(s.mean_c - t.mean_c), 3) AS mean_diff_seattle_minus_tacoma_c,
       round(stddev(s.mean_c - t.mean_c), 3) AS sd_diff_c
FROM noaa_daily s JOIN noaa_daily t ON s.d = t.d
WHERE s.station = '9447130' AND t.station = '9446484';
COPY station_overlap TO 'outputs/station_overlap.csv' (HEADER);

-- Same comparison by year (years missing part of a season mix the seasonal cycle into the annual mean; read as indicative): a step change in the difference would suggest an instrument or siting change at one station.
CREATE OR REPLACE TABLE station_overlap_by_year AS
SELECT year(s.d) AS yr, count(*) AS n_days,
       round(avg(s.mean_c), 2) AS seattle_mean_c, round(avg(t.mean_c), 2) AS tacoma_mean_c,
       round(avg(s.mean_c - t.mean_c), 2) AS mean_diff_c,
       round(corr(s.mean_c, t.mean_c), 3) AS corr_daily_mean
FROM noaa_daily s JOIN noaa_daily t ON s.d = t.d
WHERE s.station = '9447130' AND t.station = '9446484'
GROUP BY 1 ORDER BY 1;
COPY station_overlap_by_year TO 'outputs/station_overlap_by_year.csv' (HEADER);

-- Tie-break: annual mean difference of Seattle and Tacoma each relative to Port Townsend (9444900) and Friday Harbor (9449880).
-- If one station shifts relative to both reference stations while the other stays steady, the shifter is the odd one out.
-- (Reference stations are different water bodies, so this is a stability check, not a calibration.)
CREATE OR REPLACE TABLE station_stability_by_year AS
WITH a AS (
  SELECT station, year(d) AS yr, d, mean_c FROM noaa_daily WHERE year(d) BETWEEN 1997 AND 2025),
pair AS (
  SELECT x.yr, x.station, r.station AS ref_station, x.mean_c - r.mean_c AS diff
  FROM a x JOIN a r ON r.d = x.d AND r.station IN ('9444900','9449880') AND x.station IN ('9446484','9447130'))
SELECT yr, station,
       round(avg(diff) FILTER (WHERE ref_station = '9444900'), 2) AS minus_port_townsend_c,
       round(avg(diff) FILTER (WHERE ref_station = '9449880'), 2) AS minus_friday_harbor_c,
       count(*) AS n_pairs
FROM pair GROUP BY yr, station ORDER BY station, yr;
COPY station_stability_by_year TO 'outputs/station_stability_by_year.csv' (HEADER);
