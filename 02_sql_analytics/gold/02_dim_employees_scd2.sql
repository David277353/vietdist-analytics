-- Gold: dim_employees with SCD Type 2 (Subtask 3.1.2)
--
-- Your raw.employee_master already carries version + effective_date + resign_date per row —
-- the source system tracks history itself. So instead of inferring change points from load
-- timestamps, we derive effective_to directly: it's the day before the NEXT version's
-- effective_date for that employee, or the resign_date if this is their last version and
-- they resigned, or NULL/open-ended if they're still active on their latest version.
DROP TABLE IF EXISTS dwh.dim_employees;

CREATE TABLE dwh.dim_employees AS
WITH versioned AS (
    SELECT
        employee_id, full_name, gender, date_of_birth, join_date, "position",
        region, team, email, phone, status, version, effective_date, resign_date, transfer_note,
        LEAD(effective_date) OVER (PARTITION BY employee_id ORDER BY effective_date) AS next_effective_date
    FROM staging.stg_employees
    WHERE effective_date IS NOT NULL  -- can't sequence rows without an effective_date
)
SELECT
    ROW_NUMBER() OVER (ORDER BY employee_id, effective_date)      AS employee_sk,
    employee_id, full_name, gender, date_of_birth, join_date, "position",
    region, team, email, phone, status, version,
    effective_date                                                 AS effective_from,
    COALESCE(next_effective_date - INTERVAL '1 day', resign_date)::DATE AS effective_to,
    (next_effective_date IS NULL)                                  AS is_current
FROM versioned;

-- Checkpoint tests
SELECT employee_id, COUNT(*) FROM dwh.dim_employees GROUP BY employee_id HAVING COUNT(*) > 1;
-- expect: employees with multiple versions show up here with 2+ rows

SELECT employee_id, COUNT(*) FILTER (WHERE is_current) AS current_count
FROM dwh.dim_employees GROUP BY employee_id HAVING COUNT(*) FILTER (WHERE is_current) <> 1;
-- expect 0 rows — exactly one is_current=TRUE per employee

-- Join pattern for fact tables (point-in-time join):
-- SELECT * FROM fact_sales f
-- JOIN dwh.dim_employees emp
--   ON emp.employee_id = f.employee_id
--  AND f.order_date BETWEEN emp.effective_from AND COALESCE(emp.effective_to, '9999-12-31');
