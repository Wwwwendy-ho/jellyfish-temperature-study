-- 11_year_comparison.sql: year-level view (descriptive). heatwave year = >= 10 heatwave days in Jun-Oct (decided in advance).
-- With 7 years, and heatwave days and observer effort both rising after 2022, this is NOT a controlled comparison.
-- First-sighting metrics depend on how many people look, so panel records in Apr-Jun are shown next to them.
CREATE OR REPLACE TABLE year_comparison AS
WITH hw AS (SELECT year(d) AS year, count(*) AS hw_days_year, count(*) FILTER (WHERE month(d) BETWEEN 6 AND 10) AS hw_days_junoct
            FROM heatwave_days WHERE year(d) BETWEEN 2019 AND 2025 GROUP BY 1),
j AS (SELECT year, count(*) AS n_jelly,
             min(obs_date) AS first_sighting_any,
             min(obs_date) FILTER (WHERE month >= 4) AS first_sighting_from_apr1,
             (array_agg(obs_date ORDER BY obs_date) FILTER (WHERE month >= 4))[10] AS tenth_record_from_apr1
      FROM gbif_jelly_valid GROUP BY year),
p AS (SELECT year, sum(n_records) AS panel_all, sum(n_records) FILTER (WHERE month BETWEEN 4 AND 6) AS panel_apr_jun
      FROM raw_gbif_comparison GROUP BY year),
sh AS (SELECT year, sum(n_jelly) FILTER (WHERE month BETWEEN 6 AND 10) * 1.0 /
              (sum(n_jelly) FILTER (WHERE month BETWEEN 6 AND 10) + sum(n_panel) FILTER (WHERE month BETWEEN 6 AND 10)) AS junoct_share
       FROM effort_monthly GROUP BY year)
SELECT y.year, coalesce(hw.hw_days_year, 0) AS hw_days_year, coalesce(hw.hw_days_junoct, 0) AS hw_days_junoct,
       coalesce(hw.hw_days_junoct, 0) >= 10 AS is_heatwave_year,
       j.n_jelly, p.panel_all, round(sh.junoct_share, 4) AS junoct_jelly_share,
       j.first_sighting_any, j.first_sighting_from_apr1, j.tenth_record_from_apr1, p.panel_apr_jun
FROM (SELECT unnest(range(2019, 2026)) AS year) y
LEFT JOIN hw USING (year) LEFT JOIN j USING (year) LEFT JOIN p USING (year) LEFT JOIN sh USING (year) ORDER BY y.year;
COPY year_comparison TO 'outputs/year_comparison.csv' (HEADER);

CREATE OR REPLACE TABLE year_group_summary AS
SELECT is_heatwave_year, count(*) AS n_years, list(year ORDER BY year) AS years,
       round(avg(junoct_jelly_share), 4) AS mean_junoct_share,
       round(avg(dayofyear(first_sighting_from_apr1)), 1) AS mean_first_sighting_doy_from_apr1,
       round(avg(dayofyear(tenth_record_from_apr1)), 1) AS mean_tenth_record_doy_from_apr1
FROM year_comparison GROUP BY is_heatwave_year ORDER BY is_heatwave_year;
COPY year_group_summary TO 'outputs/year_group_summary.csv' (HEADER);
