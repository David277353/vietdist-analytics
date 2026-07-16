-- Silver: stg_products
DROP TABLE IF EXISTS staging.stg_products;

CREATE TABLE staging.stg_products AS
SELECT DISTINCT ON (product_id)
    product_id::TEXT                        AS product_id,
    product_name::TEXT                      AS product_name,
    category::TEXT                          AS category,
    sub_category::TEXT                      AS sub_category,
    unit::TEXT                              AS unit,
    NULLIF(unit_price, '')::NUMERIC         AS unit_price,
    NULLIF(cost_price, '')::NUMERIC         AS cost_price,
    NULLIF(weight_gram, '')::NUMERIC        AS weight_gram,
    status::TEXT                            AS status,
    NULLIF(launch_date, '')::DATE           AS launch_date,
    _ingested_at::TIMESTAMP                 AS _ingested_at
FROM raw.product_master
WHERE product_id IS NOT NULL AND product_id <> ''
ORDER BY product_id, _ingested_at DESC;

-- Tests
SELECT COUNT(*) FROM staging.stg_products WHERE product_id IS NULL; -- expect 0
SELECT product_id, COUNT(*) FROM staging.stg_products GROUP BY product_id HAVING COUNT(*) > 1; -- expect 0 rows
