-- Silver: stg_customers
DROP TABLE IF EXISTS staging.stg_customers;

CREATE TABLE staging.stg_customers AS
SELECT DISTINCT ON (customer_id)
    customer_id::TEXT                       AS customer_id,
    customer_name::TEXT                     AS customer_name,
    customer_type::TEXT                     AS customer_type,
    channel::TEXT                           AS channel,
    province::TEXT                          AS province,
    region::TEXT                            AS region,
    address::TEXT                           AS address,
    phone::TEXT                             AS phone,
    tax_code::TEXT                          AS tax_code,
    NULLIF(join_date, '')::DATE             AS join_date,
    NULLIF(credit_limit, '')::NUMERIC       AS credit_limit,
    status::TEXT                            AS status,
    _ingested_at::TIMESTAMP                 AS _ingested_at
FROM raw.customer_master
WHERE customer_id IS NOT NULL AND customer_id <> ''
ORDER BY customer_id, _ingested_at DESC;

-- Tests
SELECT COUNT(*) FROM staging.stg_customers WHERE customer_id IS NULL; -- expect 0
SELECT customer_id, COUNT(*) FROM staging.stg_customers GROUP BY customer_id HAVING COUNT(*) > 1; -- expect 0 rows
