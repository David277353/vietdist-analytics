SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE order_id IS NULL OR order_id = '') AS blank_order_id,
  COUNT(*) FILTER (WHERE order_date IS NULL OR order_date = '') AS blank_order_date,
  COUNT(DISTINCT order_id) FILTER (WHERE order_date IS NOT NULL AND order_date <> '') AS distinct_id_with_valid_date
FROM raw.sales_transactions;