-- Gold/Platinum: mart_distributor_performance
DROP TABLE IF EXISTS dwh.mart_distributor_performance;

CREATE TABLE dwh.mart_distributor_performance AS
SELECT
    d.distributor_id,
    d.distributor_name,
    d.tier,
    d.channel,
    COUNT(o.order_id)                AS order_count,
    SUM(o.gross_amount)              AS total_gross_amount,
    SUM(o.delivered_amount)          AS total_delivered_amount,
    AVG(o.fill_rate_pct)             AS avg_fill_rate_pct,
    AVG(CASE WHEN o.ontime_delivery IN ('Y', 'true', 'True', '1') THEN 1.0 ELSE 0.0 END) AS ontime_rate
FROM staging.stg_distributor_orders o
JOIN dwh.dim_distributors d ON d.distributor_id = o.distributor_id
GROUP BY d.distributor_id, d.distributor_name, d.tier, d.channel;
