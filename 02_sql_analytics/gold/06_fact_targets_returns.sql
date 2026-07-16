-- Gold: fact_targets (from the versioned target table) and fact_returns
DROP TABLE IF EXISTS dwh.fact_targets;
DROP TABLE IF EXISTS dwh.fact_returns;

CREATE TABLE dwh.fact_targets AS
SELECT
    employee_id, employee_name, region, team,
    plan_version, effective_from, effective_to,
    year, month,
    target_revenue, target_quantity, target_new_customers,
    is_latest
FROM staging.stg_sales_targets_versioned;

CREATE TABLE dwh.fact_returns AS
SELECT
    return_id,
    original_order_id,
    return_date AS date_key,
    customer_id,
    employee_id,
    product_id,
    region,
    province,
    return_quantity,
    unit_price,
    return_amount,
    return_reason,
    status
FROM staging.stg_return_transactions;
