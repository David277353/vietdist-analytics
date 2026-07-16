-- Gold: dim_distributors
-- NOTE: unlike employee_master, your raw.distributor_master has no version/effective_date
-- columns — it's a single current snapshot, not tracked history. True SCD2 isn't possible
-- from this source as-is, so this builds a SCD2-*shaped* table (so fact joins/queries don't
-- need to change later) but every row is currently open-ended (effective_to = NULL, is_current
-- = TRUE). If you get periodic distributor_master snapshots later, extend this like
-- dim_employees. Document this assumption in docs/assumptions_log.md.
DROP TABLE IF EXISTS dwh.dim_distributors;

CREATE TABLE dwh.dim_distributors AS
SELECT
    ROW_NUMBER() OVER (ORDER BY distributor_id)  AS distributor_sk,
    distributor_id, distributor_name, tier, channel, province, region,
    contact_person, phone, email, tax_code, join_date, credit_limit, status,
    assigned_supervisor_id,
    join_date                                     AS effective_from,
    NULL::DATE                                    AS effective_to,
    TRUE                                          AS is_current
FROM staging.stg_distributor_master;

-- Tests
SELECT distributor_id, COUNT(*) FROM dwh.dim_distributors GROUP BY distributor_id HAVING COUNT(*) > 1; -- expect 0
