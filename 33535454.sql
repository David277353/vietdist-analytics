SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS distinct_order_ids
FROM raw.sales_transactions;