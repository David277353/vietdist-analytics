-- Silver: stg_sales_transactions (Subtask 2.2.1) — matches actual raw.sales_transactions columns
--
-- GRAIN NOTE: order_id is an ORDER-level id, not a line-item id — raw has 119,101 rows but
-- only 50,000 distinct order_id values (~2.4 product lines per order on average). Deduping on
-- order_id alone would collapse every order down to one line and destroy most of the data.
-- The natural key for "1 row per line item" (per the brief's fact_sales grain) is
-- (order_id, product_id). Document this assumption in docs/assumptions_log.md.
DROP TABLE IF EXISTS staging.stg_sales_transactions;

CREATE TABLE staging.stg_sales_transactions AS
SELECT DISTINCT ON (order_id, product_id)
    order_id::TEXT                              AS order_id,
    NULLIF(order_date, '')::DATE                 AS order_date,
    NULLIF(order_month, '')::INT                 AS order_month,
    NULLIF(order_quarter, '')::INT               AS order_quarter,
    NULLIF(order_year, '')::INT                  AS order_year,
    customer_id::TEXT                            AS customer_id,
    region::TEXT                                 AS region,
    province::TEXT                               AS province,
    channel::TEXT                                AS channel,
    employee_id::TEXT                            AS employee_id,
    product_id::TEXT                             AS product_id,
    product_category::TEXT                       AS product_category,
    NULLIF(quantity, '')::NUMERIC                AS quantity,
    NULLIF(unit_price, '')::NUMERIC              AS unit_price,
    NULLIF(discount_pct, '')::NUMERIC            AS discount_pct,
    NULLIF(discount_amount, '')::NUMERIC         AS discount_amount,
    NULLIF(gross_amount, '')::NUMERIC            AS gross_amount,
    NULLIF(net_amount, '')::NUMERIC              AS net_amount,
    delivery_status::TEXT                        AS delivery_status,
    payment_method::TEXT                         AS payment_method,
    payment_status::TEXT                         AS payment_status,
    _source_file,
    _ingested_at::TIMESTAMP                      AS _ingested_at
FROM raw.sales_transactions
WHERE order_id IS NOT NULL AND order_id <> ''
  AND order_date IS NOT NULL AND order_date <> ''
  AND product_id IS NOT NULL AND product_id <> ''
ORDER BY order_id, product_id, _ingested_at DESC;

-- Data quality tests (Subtask 2.2.2)
SELECT COUNT(*) AS null_pk_count FROM staging.stg_sales_transactions WHERE order_id IS NULL; -- expect 0
SELECT order_id, product_id, COUNT(*) FROM staging.stg_sales_transactions
GROUP BY order_id, product_id HAVING COUNT(*) > 1; -- expect 0 rows
-- Row count sanity check: should be close to raw's 119,101 (minus true duplicate re-loads, if any)
SELECT COUNT(*) AS staging_row_count FROM staging.stg_sales_transactions;
