-- Silver: stg_employees
-- NOTE: your raw.employee_master already carries 'version' + 'effective_date' + 'resign_date' —
-- the source system is tracking history itself. Keep every row (don't dedupe by employee_id);
-- SCD2 in dwh.dim_employees (gold/02) will use effective_date directly instead of inferring
-- change points from load timestamps.
DROP TABLE IF EXISTS staging.stg_employees;

CREATE TABLE staging.stg_employees AS
SELECT
    employee_id::TEXT                       AS employee_id,
    full_name::TEXT                         AS full_name,
    gender::TEXT                            AS gender,
    NULLIF(date_of_birth, '')::DATE         AS date_of_birth,
    NULLIF(join_date, '')::DATE             AS join_date,
    "position"::TEXT                        AS "position",
    region::TEXT                            AS region,
    team::TEXT                              AS team,
    email::TEXT                             AS email,
    phone::TEXT                             AS phone,
    status::TEXT                            AS status,
    NULLIF(version, '')::TEXT               AS version,  -- text like 'v1', 'v2', not numeric
    NULLIF(effective_date, '')::DATE        AS effective_date,
    NULLIF(resign_date, '')::DATE           AS resign_date,
    transfer_note::TEXT                     AS transfer_note,
    _ingested_at::TIMESTAMP                 AS _ingested_at
FROM raw.employee_master
WHERE employee_id IS NOT NULL AND employee_id <> ''
-- de-dup exact duplicate rows only (same employee_id + same version)
;

-- Tests
SELECT COUNT(*) FROM staging.stg_employees WHERE employee_id IS NULL; -- expect 0
SELECT employee_id, version, COUNT(*) FROM staging.stg_employees
GROUP BY employee_id, version HAVING COUNT(*) > 1; -- expect 0 rows (dup versions)
