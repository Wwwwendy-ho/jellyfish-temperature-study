-- 10_monthly_heatwave.sql: heatwave vs normal months (Q5) and species / calendar-month rankings (Q6).
-- Decisions fixed before looking at jellyfish ratios:
--   heatwave month = >= 5 heatwave days (primary baseline events) in that calendar month;
--   main season = Jun-Oct (jellyfish share ~10% vs ~1% in winter); sensitivities: all months, >=10 days, >=1 day;
--   adjustment: subtract the calendar-month mean share (season), then the year mean of what is left (year effect:
--   absorbs the rise in observer effort and heatwave days after 2022). The contrast is therefore within-year.
CREATE OR REPLACE TABLE heatwave_days AS
SELECT a.d FROM tacoma_daily_anom a
JOIN heatwave_events e ON e.baseline = a.baseline AND a.d BETWEEN e.start_date AND e.end_date
WHERE a.baseline = 'excl_2007_2017';

CREATE OR REPLACE TABLE monthly_hw AS
WITH hw AS (SELECT CAST(date_trunc('month', d) AS DATE) AS month_start, count(*) AS hw_days FROM heatwave_days GROUP BY 1),
     obs AS (SELECT CAST(date_trunc('month', d) AS DATE) AS month_start, count(*) AS days_observed
             FROM tacoma_daily_anom WHERE baseline = 'excl_2007_2017' GROUP BY 1)
SELECT e.*, coalesce(hw.hw_days, 0) AS hw_days, obs.days_observed,
       coalesce(hw.hw_days, 0) * 1.0 / day(last_day(e.month_start)) AS hw_fraction
FROM effort_monthly e LEFT JOIN hw USING (month_start) LEFT JOIN obs USING (month_start);
COPY (SELECT * FROM monthly_hw ORDER BY month_start) TO 'outputs/monthly_heatwave_effort.csv' (HEADER);

CREATE OR REPLACE TABLE analysis_spec AS
SELECT * FROM (VALUES ('primary_JunOct_5d', 6, 10, 5), ('all_months_5d', 1, 12, 5),
                      ('JunOct_10d', 6, 10, 10), ('JunOct_any_day', 6, 10, 1)) t(analysis_id, m_lo, m_hi, hw_min_days);

-- Two-way adjusted share anomaly per analysis spec.
CREATE OR REPLACE TABLE monthly_adj AS
WITH base AS (
  SELECT s.analysis_id, m.*, m.hw_days >= s.hw_min_days AS is_hw_month
  FROM monthly_hw m JOIN analysis_spec s ON m.month BETWEEN s.m_lo AND s.m_hi),
cal AS (SELECT analysis_id, month, avg(jelly_share) AS cal_mean FROM base GROUP BY 1, 2),
s1 AS (SELECT b.*, b.jelly_share - c.cal_mean AS anom_cal FROM base b JOIN cal c USING (analysis_id, month)),
yr AS (SELECT analysis_id, year, avg(anom_cal) AS year_effect FROM s1 GROUP BY 1, 2)
SELECT s1.*, s1.anom_cal - yr.year_effect AS anom_adj
FROM s1 JOIN yr USING (analysis_id, year);

CREATE OR REPLACE TABLE heatwave_vs_normal_summary AS
WITH both_groups AS (  -- years that contain at least one heatwave and one normal month (the only years that inform the contrast)
  SELECT analysis_id, year FROM monthly_adj GROUP BY 1, 2 HAVING count(*) FILTER (WHERE is_hw_month) > 0 AND count(*) FILTER (WHERE NOT is_hw_month) > 0)
SELECT a.analysis_id,
       count(*) FILTER (WHERE is_hw_month) AS n_hw_months, count(*) FILTER (WHERE NOT is_hw_month) AS n_normal_months,
       (SELECT count(*) FROM both_groups g WHERE g.analysis_id = a.analysis_id) AS n_informative_years,
       round(avg(jelly_share) FILTER (WHERE is_hw_month), 4) AS raw_mean_share_hw,
       round(avg(jelly_share) FILTER (WHERE NOT is_hw_month), 4) AS raw_mean_share_normal,
       round(avg(anom_adj) FILTER (WHERE is_hw_month), 4) AS adj_anomaly_hw,
       round(avg(anom_adj) FILTER (WHERE NOT is_hw_month), 4) AS adj_anomaly_normal,
       round(avg(anom_adj) FILTER (WHERE is_hw_month) - avg(anom_adj) FILTER (WHERE NOT is_hw_month), 4) AS adj_difference,
       round(corr(hw_fraction, anom_adj), 3) AS pearson_hwfraction_vs_adj_anomaly
FROM monthly_adj a GROUP BY a.analysis_id ORDER BY a.analysis_id;
COPY heatwave_vs_normal_summary TO 'outputs/heatwave_vs_normal_summary.csv' (HEADER);

-- Per-year contrast for the primary spec (years with both group types): is the sign consistent across years?
CREATE OR REPLACE TABLE heatwave_vs_normal_by_year AS
SELECT year, count(*) FILTER (WHERE is_hw_month) AS n_hw_months, count(*) FILTER (WHERE NOT is_hw_month) AS n_normal_months,
       round(avg(jelly_share) FILTER (WHERE is_hw_month), 4) AS mean_share_hw,
       round(avg(jelly_share) FILTER (WHERE NOT is_hw_month), 4) AS mean_share_normal,
       round(avg(anom_cal) FILTER (WHERE is_hw_month) - avg(anom_cal) FILTER (WHERE NOT is_hw_month), 4) AS season_adjusted_difference
FROM monthly_adj WHERE analysis_id = 'primary_JunOct_5d'
GROUP BY year HAVING count(*) FILTER (WHERE is_hw_month) > 0 AND count(*) FILTER (WHERE NOT is_hw_month) > 0 ORDER BY year;
COPY heatwave_vs_normal_by_year TO 'outputs/heatwave_vs_normal_by_year.csv' (HEADER);

-- Q6a: which species group shifts most in heatwave months (primary spec). Species share = species records / (all jellyfish + panel).
CREATE OR REPLACE TABLE species_monthly AS
WITH grp AS (SELECT DISTINCT species_group FROM jelly_species_monthly),
     grid AS (SELECT m.*, g.species_group FROM monthly_hw m CROSS JOIN grp g WHERE m.month BETWEEN 6 AND 10),
     sp AS (SELECT year, month, species_group, n_jelly AS n_species FROM jelly_species_monthly)
SELECT grid.species_group, grid.year, grid.month, grid.hw_days >= 5 AS is_hw_month,
       coalesce(sp.n_species, 0) AS n_species,
       coalesce(sp.n_species, 0) * 1.0 / (grid.n_jelly + grid.n_panel) AS species_share
FROM grid LEFT JOIN sp USING (species_group, year, month);

CREATE OR REPLACE TABLE species_shift_ranking AS
WITH cal AS (SELECT species_group, month, avg(species_share) AS cal_mean FROM species_monthly GROUP BY 1, 2),
a1 AS (SELECT s.*, s.species_share - c.cal_mean AS anom_cal FROM species_monthly s JOIN cal c USING (species_group, month)),
yr AS (SELECT species_group, year, avg(anom_cal) AS year_effect FROM a1 GROUP BY 1, 2),
a2 AS (SELECT a1.*, a1.anom_cal - yr.year_effect AS anom_adj FROM a1 JOIN yr USING (species_group, year)),
agg AS (
  SELECT species_group, sum(n_species) FILTER (WHERE is_hw_month) AS records_in_hw_months, sum(n_species) AS records_total,
         avg(species_share) AS mean_share_all,
         avg(anom_adj) FILTER (WHERE is_hw_month) - avg(anom_adj) FILTER (WHERE NOT is_hw_month) AS adj_difference
  FROM a2 GROUP BY species_group)
SELECT species_group, records_in_hw_months, records_total, round(mean_share_all, 4) AS mean_share_all,
       round(adj_difference, 4) AS adj_difference, round(adj_difference / mean_share_all, 3) AS relative_difference,
       rank() OVER (ORDER BY adj_difference / mean_share_all DESC) AS rank_by_relative_shift
FROM agg ORDER BY rank_by_relative_shift;
COPY species_shift_ranking TO 'outputs/species_shift_ranking.csv' (HEADER);

-- Q6b: which calendar months differ most between heatwave and normal years (primary spec; needs >= 1 month of each kind).
CREATE OR REPLACE TABLE month_shift_ranking AS
SELECT month, count(*) FILTER (WHERE is_hw_month) AS n_hw_years, count(*) FILTER (WHERE NOT is_hw_month) AS n_normal_years,
       round(avg(jelly_share) FILTER (WHERE is_hw_month), 4) AS mean_share_hw,
       round(avg(jelly_share) FILTER (WHERE NOT is_hw_month), 4) AS mean_share_normal,
       round(avg(anom_adj) FILTER (WHERE is_hw_month) - avg(anom_adj) FILTER (WHERE NOT is_hw_month), 4) AS adj_difference,
       rank() OVER (ORDER BY abs(avg(anom_adj) FILTER (WHERE is_hw_month) - avg(anom_adj) FILTER (WHERE NOT is_hw_month)) DESC) AS rank_by_abs_shift
FROM monthly_adj WHERE analysis_id = 'primary_JunOct_5d'
GROUP BY month HAVING count(*) FILTER (WHERE is_hw_month) > 0 AND count(*) FILTER (WHERE NOT is_hw_month) > 0
ORDER BY rank_by_abs_shift;
COPY month_shift_ranking TO 'outputs/month_shift_ranking.csv' (HEADER);
