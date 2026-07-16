-- Silver: stg_sales_targets_versioned (Subtask 2.3.2)
--
-- IMPORTANT: your actual source (raw.sales_target_plan_raw) is NOT the wide T1..T12 layout
-- described in the brief — it already comes long-format with plan_version, effective_from,
-- effective_to, year, month. That means the source system already tells you which version
-- is effective for which period, so we don't need to infer it from version numbers.
--
-- Logic: for each employee + year + month, the "latest" row is the one whose effective_from
-- is the most recent (and effective_to is either NULL/blank or in the future / covers that month).
DROP TABLE IF EXISTS staging.stg_sales_targets_versioned;

CREATE TABLE staging.stg_sales_targets_versioned AS
WITH parsed AS (
    SELECT
        employee_id::TEXT                        AS employee_id,
        employee_name::TEXT                      AS employee_name,
        region::TEXT                              AS region,
        team::TEXT                                AS team,
        NULLIF(plan_version, '')::TEXT           AS plan_version,
        NULLIF(version_date, '')::DATE           AS version_date,
        NULLIF(effective_from, '')::DATE         AS effective_from,
        NULLIF(effective_to, '')::DATE           AS effective_to,
        NULLIF(year, '')::INT                    AS year,
        NULLIF(month, '')::INT                   AS month,
        NULLIF(target_revenue, '')::NUMERIC      AS target_revenue,
        NULLIF(target_quantity, '')::NUMERIC     AS target_quantity,
        NULLIF(target_new_customers, '')::NUMERIC AS target_new_customers,
        _source_file,
        _ingested_at::TIMESTAMP                  AS _ingested_at
    FROM raw.sales_target_plan_raw
    WHERE employee_id IS NOT NULL AND employee_id <> ''
      AND year IS NOT NULL AND year <> ''
      AND month IS NOT NULL AND month <> ''
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY employee_id, year, month
            ORDER BY effective_from DESC NULLS LAST, version_date DESC NULLS LAST
        ) AS rn
    FROM parsed
)
SELECT
    employee_id, employee_name, region, team,
    plan_version, version_date, effective_from, effective_to,
    year, month, target_revenue, target_quantity, target_new_customers,
    _source_file, _ingested_at,
    (rn = 1) AS is_latest
FROM ranked;

-- Sanity checks (Subtask 2.3.3)
-- Every employee+year+month should have exactly one is_latest = TRUE row
SELECT employee_id, year, month, COUNT(*) FILTER (WHERE is_latest)
FROM staging.stg_sales_targets_versioned
GROUP BY employee_id, year, month
HAVING COUNT(*) FILTER (WHERE is_latest) <> 1; -- expect 0 rows

-- See how many versions exist per employee+month (to confirm versioning is actually happening)
SELECT employee_id, year, month, COUNT(*) AS version_count
FROM staging.stg_sales_targets_versioned
GROUP BY employee_id, year, month
ORDER BY version_count DESC
LIMIT 20;
