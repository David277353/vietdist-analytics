-- Gold: fact_sales (Subtask 3.2.1) — grain: 1 row per (order_id, product_id) line item
-- Keeps natural keys (order_id/customer_id/product_id/employee_id) alongside surrogate keys —
-- natural keys make the mart queries in 07/08 much simpler to write and debug.
DROP TABLE IF EXISTS dwh.fact_sales;

CREATE TABLE dwh.fact_sales AS
SELECT
    t.order_id,
    t.product_id,
    t.customer_id,
    t.employee_id,
    t.order_date                                AS date_key,
    c.customer_sk,
    p.product_sk,
    emp.employee_sk,
    t.quantity,
    t.unit_price,
    t.discount_pct,
    t.discount_amount,
    t.gross_amount,
    t.net_amount,
    t.region,
    t.province,
    t.channel,
    t.delivery_status,
    t.payment_method,
    t.payment_status
FROM staging.stg_sales_transactions t
LEFT JOIN dwh.dim_customers c   ON c.customer_id = t.customer_id
LEFT JOIN dwh.dim_products  p   ON p.product_id  = t.product_id
LEFT JOIN dwh.dim_employees emp ON emp.employee_id = t.employee_id
                                AND t.order_date BETWEEN emp.effective_from
                                                      AND COALESCE(emp.effective_to, '9999-12-31');

-- Data quality checks — investigate any of these that come back non-zero
SELECT COUNT(*) FROM dwh.fact_sales WHERE customer_sk IS NULL; -- orphan customers
SELECT COUNT(*) FROM dwh.fact_sales WHERE product_sk IS NULL;  -- orphan products
SELECT COUNT(*) FROM dwh.fact_sales WHERE employee_sk IS NULL; -- unmatched employee date ranges
SELECT COUNT(*) FROM dwh.fact_sales; -- should match staging.stg_sales_transactions row count
