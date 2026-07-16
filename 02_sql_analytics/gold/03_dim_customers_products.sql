-- Gold: dim_customers (SCD1 — overwrite, no history) and dim_products (SCD1)
DROP TABLE IF EXISTS dwh.dim_customers;
DROP TABLE IF EXISTS dwh.dim_products;

CREATE TABLE dwh.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_sk,
    customer_id, customer_name, customer_type, channel, province, region,
    address, phone, tax_code, join_date, credit_limit, status
FROM staging.stg_customers;

CREATE TABLE dwh.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id) AS product_sk,
    product_id, product_name, category, sub_category, unit,
    unit_price, cost_price, weight_gram, status, launch_date
FROM staging.stg_products;

-- Tests
SELECT customer_id, COUNT(*) FROM dwh.dim_customers GROUP BY customer_id HAVING COUNT(*) > 1; -- expect 0
SELECT product_id, COUNT(*) FROM dwh.dim_products GROUP BY product_id HAVING COUNT(*) > 1; -- expect 0
