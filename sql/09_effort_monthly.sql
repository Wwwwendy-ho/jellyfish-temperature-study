-- 09_effort_monthly.sql: effort-corrected monthly jellyfish share.
-- share = jellyfish / (jellyfish + comparison panel) per month, all from the same iNaturalist dataset and box.
-- Panel (chosen before looking at ratios): Echinodermata, Decapoda, Phocidae, Otariidae, Cetacea.
CREATE OR REPLACE TABLE month_spine AS
SELECT CAST(m AS DATE) AS month_start, year(m) AS year, month(m) AS month
FROM (SELECT unnest(generate_series(DATE '2019-01-01', DATE '2025-12-01', INTERVAL 1 MONTH)) AS m);

CREATE OR REPLACE TABLE jelly_species_monthly AS
SELECT year, month,
       CASE WHEN species IN ('Phacellophora camtschatica', 'Cyanea ferruginea', 'Aurelia labiata') THEN species ELSE 'other / unresolved' END AS species_group,
       count(*) AS n_jelly
FROM gbif_jelly_valid GROUP BY ALL;
COPY (SELECT * FROM jelly_species_monthly ORDER BY year, month, species_group) TO 'outputs/jellyfish_species_monthly.csv' (HEADER);

CREATE OR REPLACE TABLE effort_monthly AS
WITH j AS (SELECT year, month, count(*) AS n_jelly FROM gbif_jelly_valid GROUP BY ALL),
     c AS (SELECT year, month, sum(n_records) AS n_panel FROM raw_gbif_comparison GROUP BY ALL)
SELECT s.month_start, s.year, s.month,
       coalesce(j.n_jelly, 0) AS n_jelly, coalesce(c.n_panel, 0) AS n_panel,
       CASE WHEN coalesce(j.n_jelly, 0) + coalesce(c.n_panel, 0) > 0
            THEN round(coalesce(j.n_jelly, 0) * 1.0 / (coalesce(j.n_jelly, 0) + coalesce(c.n_panel, 0)), 4) END AS jelly_share
FROM month_spine s LEFT JOIN j USING (year, month) LEFT JOIN c USING (year, month)
ORDER BY s.month_start;
COPY effort_monthly TO 'outputs/effort_monthly.csv' (HEADER);

-- Sensitivity: share against each comparison group on its own.
CREATE OR REPLACE TABLE effort_monthly_by_group AS
SELECT s.month_start, c.group_name, coalesce(j.n_jelly, 0) AS n_jelly, c.n_records AS n_group,
       CASE WHEN coalesce(j.n_jelly, 0) + c.n_records > 0
            THEN round(coalesce(j.n_jelly, 0) * 1.0 / (coalesce(j.n_jelly, 0) + c.n_records), 4) END AS jelly_share
FROM month_spine s
JOIN raw_gbif_comparison c ON c.year = s.year AND c.month = s.month
LEFT JOIN (SELECT year, month, count(*) AS n_jelly FROM gbif_jelly_valid GROUP BY ALL) j ON j.year = s.year AND j.month = s.month
ORDER BY c.group_name, s.month_start;
COPY effort_monthly_by_group TO 'outputs/effort_monthly_by_group.csv' (HEADER);

-- Pooled share by calendar month (sum of jellyfish / sum of jellyfish + panel over 2019-2025): the seasonal pattern.
CREATE OR REPLACE TABLE effort_by_calendar_month AS
SELECT month, sum(n_jelly) AS n_jelly, sum(n_panel) AS n_panel,
       round(sum(n_jelly) * 1.0 / (sum(n_jelly) + sum(n_panel)), 4) AS pooled_share
FROM effort_monthly GROUP BY month ORDER BY month;
COPY effort_by_calendar_month TO 'outputs/effort_by_calendar_month.csv' (HEADER);

-- Comparison-panel records per group and year (shows how fast each group's records grew, i.e. how neutral the denominator is).
CREATE OR REPLACE TABLE panel_group_yearly AS
SELECT group_name, year, sum(n_records) AS n_records FROM raw_gbif_comparison GROUP BY ALL ORDER BY group_name, year;
COPY panel_group_yearly TO 'outputs/panel_group_yearly.csv' (HEADER);
