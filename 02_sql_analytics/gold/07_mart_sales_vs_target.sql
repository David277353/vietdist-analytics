-- Gold/Platinum: mart_sales_vs_target (Subtask 3.2.2) — the mart Power BI reads from
-- Grain: one row per employee x year x month, comparing actual sales to the LATEST effective target.
DROP TABLE IF EXISTS dwh.mart_sales_vs_target;

CREATE TABLE dwh.mart_sales_vs_target AS
WITH actuals AS (
    SELECT
        employee_id,
        EXTRACT(YEAR FROM date_key)::INT  AS year,
        EXTRACT(MONTH FROM date_key)::INT AS month,
        SUM(net_amount)                   AS actual_sales
    FROM dwh.fact_sales
    WHERE employee_id IS NOT NULL
    GROUP BY employee_id, EXTRACT(YEAR FROM date_key), EXTRACT(MONTH FROM date_key)
),
targets AS (
    SELECT employee_id, year, month, target_revenue
    FROM dwh.fact_targets
    WHERE is_latest  -- always use the currently-effective version
)
SELECT
    a.employee_id,
    a.year,
    a.month,
    a.actual_sales,
    t.target_revenue,
    ROUND(a.actual_sales - COALESCE(t.target_revenue, 0), 2)             AS variance_abs,
    ROUND(100.0 * a.actual_sales / NULLIF(t.target_revenue, 0), 1)       AS achievement_pct
FROM actuals a
LEFT JOIN targets t
    ON t.employee_id = a.employee_id AND t.year = a.year AND t.month = a.month;

-- Sanity check
SELECT COUNT(*) FROM dwh.mart_sales_vs_target WHERE target_revenue IS NULL; -- investigate if high
