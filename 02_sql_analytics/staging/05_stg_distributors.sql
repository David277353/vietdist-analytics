-- Silver: stg_distributor_master + stg_distributor_orders
DROP TABLE IF EXISTS staging.stg_distributor_master;
DROP TABLE IF EXISTS staging.stg_distributor_orders;

CREATE TABLE staging.stg_distributor_master AS
SELECT DISTINCT ON (distributor_id)
    distributor_id::TEXT                    AS distributor_id,
    distributor_name::TEXT                  AS distributor_name,
    tier::TEXT                              AS tier,
    channel::TEXT                           AS channel,
    province::TEXT                          AS province,
    region::TEXT                            AS region,
    contact_person::TEXT                    AS contact_person,
    phone::TEXT                             AS phone,
    email::TEXT                             AS email,
    tax_code::TEXT                          AS tax_code,
    NULLIF(join_date, '')::DATE             AS join_date,
    NULLIF(credit_limit, '')::NUMERIC       AS credit_limit,
    status::TEXT                            AS status,
    assigned_supervisor_id::TEXT            AS assigned_supervisor_id,
    _ingested_at::TIMESTAMP                 AS _ingested_at
FROM raw.distributor_master
WHERE distributor_id IS NOT NULL AND distributor_id <> ''
ORDER BY distributor_id, _ingested_at DESC;

CREATE TABLE staging.stg_distributor_orders AS
SELECT DISTINCT ON (order_id)
    order_id::TEXT                          AS order_id,
    NULLIF(order_date, '')::DATE            AS order_date,
    NULLIF(order_month, '')::INT            AS order_month,
    NULLIF(order_quarter, '')::INT          AS order_quarter,
    distributor_id::TEXT                    AS distributor_id,
    region::TEXT                            AS region,
    channel::TEXT                           AS channel,
    product_id::TEXT                        AS product_id,
    product_category::TEXT                  AS product_category,
    NULLIF(qty_ordered, '')::NUMERIC        AS qty_ordered,
    NULLIF(qty_delivered, '')::NUMERIC      AS qty_delivered,
    NULLIF(fill_rate_pct, '')::NUMERIC      AS fill_rate_pct,
    NULLIF(unit_price_list, '')::NUMERIC    AS unit_price_list,
    NULLIF(distributor_price, '')::NUMERIC  AS distributor_price,
    NULLIF(gross_amount, '')::NUMERIC       AS gross_amount,
    NULLIF(delivered_amount, '')::NUMERIC   AS delivered_amount,
    NULLIF(expected_delivery_date, '')::DATE AS expected_delivery_date,
    NULLIF(actual_delivery_date, '')::DATE   AS actual_delivery_date,
    ontime_delivery::TEXT                   AS ontime_delivery,
    delivery_status::TEXT                   AS delivery_status,
    payment_terms::TEXT                     AS payment_terms,
    _ingested_at::TIMESTAMP                 AS _ingested_at
FROM raw.distributor_orders
WHERE order_id IS NOT NULL AND order_id <> ''
ORDER BY order_id, _ingested_at DESC;

-- Tests
SELECT distributor_id, COUNT(*) FROM staging.stg_distributor_master GROUP BY distributor_id HAVING COUNT(*) > 1; -- expect 0 rows
SELECT order_id, COUNT(*) FROM staging.stg_distributor_orders GROUP BY order_id HAVING COUNT(*) > 1; -- expect 0 rows
