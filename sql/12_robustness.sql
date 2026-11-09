-- 12_robustness.sql: how stable is the heatwave-vs-normal estimate? (Jun-Oct, panel-relative jellyfish share)
-- Estimator: two-way fixed effects. Share y and heatwave flag x (1 if >= 5 heatwave days that month) are each demeaned by
-- calendar month and then by year, and beta = sum(x*y) / sum(x*x) on the demeaned values. This is the regression of y on x
-- with month and year dummies (the panel is balanced, so demeaning in sequence is exact). Both y AND x are residualised;
-- 10_monthly_heatwave.sql only residualises y, which pulls its 'adj_difference' toward zero.
-- se_unclustered ignores that months within a year are correlated, so it is probably too small. Not a significance test.
CREATE OR REPLACE TABLE hw_days_by_baseline AS
SELECT a.baseline, a.d FROM tacoma_daily_anom a
JOIN heatwave_events e ON e.baseline = a.baseline AND a.d BETWEEN e.start_date AND e.end_date;

CREATE OR REPLACE TABLE rob_month_hw AS
WITH m AS (SELECT baseline, CAST(date_trunc('month', d) AS DATE) AS month_start, count(*) AS hw_days FROM hw_days_by_baseline GROUP BY 1, 2)
SELECT b.baseline, s.month_start, s.year, s.month, coalesce(m.hw_days, 0) AS hw_days
FROM (SELECT DISTINCT baseline FROM heatwave_events) b CROSS JOIN month_spine s
LEFT JOIN m ON m.baseline = b.baseline AND m.month_start = s.month_start
WHERE s.month BETWEEN 6 AND 10;

CREATE OR REPLACE TABLE rob_cells AS
SELECT 'primary_5d' AS variant, h.year, h.month, e.jelly_share AS y, CAST(h.hw_days >= 5 AS INTEGER) AS x
  FROM rob_month_hw h JOIN effort_monthly e USING (month_start) WHERE h.baseline = 'excl_2007_2017'
UNION ALL SELECT 'threshold_10d', h.year, h.month, e.jelly_share, CAST(h.hw_days >= 10 AS INTEGER)
  FROM rob_month_hw h JOIN effort_monthly e USING (month_start) WHERE h.baseline = 'excl_2007_2017'
UNION ALL SELECT 'any_heatwave_day', h.year, h.month, e.jelly_share, CAST(h.hw_days >= 1 AS INTEGER)
  FROM rob_month_hw h JOIN effort_monthly e USING (month_start) WHERE h.baseline = 'excl_2007_2017'
UNION ALL SELECT 'full_baseline_5d', h.year, h.month, e.jelly_share, CAST(h.hw_days >= 5 AS INTEGER)
  FROM rob_month_hw h JOIN effort_monthly e USING (month_start) WHERE h.baseline = 'full_1998_2025'
UNION ALL SELECT 'drop_year_' || CAST(y.yr AS VARCHAR), h.year, h.month, e.jelly_share, CAST(h.hw_days >= 5 AS INTEGER)
  FROM rob_month_hw h JOIN effort_monthly e USING (month_start)
  CROSS JOIN (SELECT unnest(range(2019, 2026)) AS yr) y WHERE h.baseline = 'excl_2007_2017' AND h.year <> y.yr
UNION ALL SELECT 'panel_only_' || g.group_name, h.year, h.month, g.jelly_share, CAST(h.hw_days >= 5 AS INTEGER)
  FROM rob_month_hw h JOIN effort_monthly_by_group g USING (month_start) WHERE h.baseline = 'excl_2007_2017';

CREATE OR REPLACE TABLE robustness_fe_estimates AS
WITH d1 AS (SELECT *, y - avg(y) OVER (PARTITION BY variant, month) AS y1, x - avg(x) OVER (PARTITION BY variant, month) AS x1 FROM rob_cells),
     d2 AS (SELECT *, y1 - avg(y1) OVER (PARTITION BY variant, year) AS y2, x1 - avg(x1) OVER (PARTITION BY variant, year) AS x2 FROM d1),
     fit AS (SELECT variant, count(*) AS n_months, count(DISTINCT year) AS n_years, sum(x) AS n_hw_months,
                    sum(x2 * y2) / nullif(sum(x2 * x2), 0) AS beta, sum(x2 * x2) AS sxx, sum(y2 * y2) AS syy, sum(x2 * y2) AS sxy FROM d2 GROUP BY variant)
SELECT variant, n_months, n_years, n_hw_months,
       -- round to 8 places first so parallel-sum float noise cannot flip the 4th decimal on a boundary value
       round(round(beta, 8), 4) AS fe_estimate,
       round(round(sqrt(((syy - beta * sxy) / (n_months - n_years - 4)) / sxx), 8), 4) AS se_unclustered   -- df = n - (4 month dummies) - (years - 1) - 1
FROM fit
ORDER BY CASE WHEN variant = 'primary_5d' THEN 0 WHEN variant LIKE 'drop_year_%' THEN 2 WHEN variant LIKE 'panel_only_%' THEN 3 ELSE 1 END, variant;
COPY robustness_fe_estimates TO 'outputs/robustness_fe_estimates.csv' (HEADER);
