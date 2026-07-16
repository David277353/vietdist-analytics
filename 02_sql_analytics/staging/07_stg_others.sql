-- Silver: territory_mapping, promotion_program, return_transactions
DROP TABLE IF EXISTS staging.stg_territory_mapping;
DROP TABLE IF EXISTS staging.stg_promotion_program;
DROP TABLE IF EXISTS staging.stg_return_transactions;

CREATE TABLE staging.stg_territory_mapping AS
SELECT
    territory_id::TEXT                      AS territory_id,
    employee_id::TEXT                       AS employee_id,
    customer_id::TEXT                       AS customer_id,
    region::TEXT                            AS region,
    team::TEXT                              AS team,
    NULLIF(effective_date, '')::DATE        AS effective_date,
    NULLIF(expiry_date, '')::DATE           AS expiry_date,
    NULLIF(version, '')::TEXT               AS version,  -- likely text like 'v1', not numeric
    _ingested_at::TIMESTAMP                 AS _ingested_at
FROM raw.territory_mapping
WHERE territory_id IS NOT NULL AND territory_id <> '';

CREATE TABLE staging.stg_promotion_program AS
SELECT DISTINCT ON (promotion_id)
    promotion_id::TEXT                      AS promotion_id,
    promotion_name::TEXT                    AS promotion_name,
    promotion_type::TEXT                    AS promotion_type,
    target_channel::TEXT                    AS target_channel,
    target_region::TEXT                     AS target_region,
    NULLIF(start_date, '')::DATE            AS start_date,
    NULLIF(end_date, '')::DATE              AS end_date,
    applicable_products::TEXT               AS applicable_products,
    NULLIF(discount_pct, '')::NUMERIC       AS discount_pct,
    NULLIF(min_order_quantity, '')::NUMERIC AS min_order_quantity,
    NULLIF(budget_vnd, '')::NUMERIC         AS budget_vnd,
    NULLIF(actual_cost_vnd, '')::NUMERIC    AS actual_cost_vnd,
    status::TEXT                            AS status,
    created_by::TEXT                        AS created_by,
    program_name::TEXT                      AS program_name,  -- sheet tag added at load time
    _ingested_at::TIMESTAMP                 AS _ingested_at
FROM raw.promotion_program
WHERE promotion_id IS NOT NULL AND promotion_id <> ''
ORDER BY promotion_id, _ingested_at DESC;

CREATE TABLE staging.stg_return_transactions AS
SELECT DISTINCT ON (return_id)
    return_id::TEXT                         AS return_id,
    original_order_id::TEXT                 AS original_order_id,
    NULLIF(return_date, '')::DATE           AS return_date,
    NULLIF(return_month, '')::INT           AS return_month,
    customer_id::TEXT                       AS customer_id,
    employee_id::TEXT                       AS employee_id,
    product_id::TEXT                        AS product_id,
    region::TEXT                            AS region,
    province::TEXT                          AS province,
    NULLIF(return_quantity, '')::NUMERIC    AS return_quantity,
    NULLIF(unit_price, '')::NUMERIC         AS unit_price,
    NULLIF(return_amount, '')::NUMERIC      AS return_amount,
    return_reason::TEXT                     AS return_reason,
    status::TEXT                            AS status,
    _ingested_at::TIMESTAMP                 AS _ingested_at
FROM raw.return_transactions
WHERE return_id IS NOT NULL AND return_id <> ''
ORDER BY return_id, _ingested_at DESC;

-- Tests
SELECT territory_id, COUNT(*) FROM staging.stg_territory_mapping GROUP BY territory_id HAVING COUNT(*) > 1;
SELECT promotion_id, COUNT(*) FROM staging.stg_promotion_program GROUP BY promotion_id HAVING COUNT(*) > 1; -- expect 0 rows
SELECT return_id, COUNT(*) FROM staging.stg_return_transactions GROUP BY return_id HAVING COUNT(*) > 1; -- expect 0 rows
