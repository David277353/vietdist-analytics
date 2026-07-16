-- Gold: dim_date (Subtask 3.1.1) — static calendar table, 2022-01-01 to 2026-12-31
-- Fiscal year: assume FY starts September (adjust MONTH() threshold below if your
-- brief defines FY differently). Per the checkpoint:
--   2023-10-01 -> fiscal_year = 2023  (Oct is month 10, in FY2023 which runs Sep'23-Aug'24)
--   2024-01-01 -> fiscal_year = 2023  (Jan is still within FY2023, ends Aug'24)
-- So: if month >= 9 (Sep-Dec) -> fiscal_year = year; else -> fiscal_year = year - 1

CREATE TABLE dwh.dim_date AS
SELECT
    d::DATE                                        AS date_key,
    EXTRACT(YEAR FROM d)::INT                       AS year,
    EXTRACT(QUARTER FROM d)::INT                    AS quarter,
    EXTRACT(MONTH FROM d)::INT                      AS month,
    TO_CHAR(d, 'Month')                             AS month_name,
    EXTRACT(WEEK FROM d)::INT                       AS week_of_year,
    EXTRACT(DAY FROM d)::INT                        AS day_of_month,
    EXTRACT(DOW FROM d)::INT                         AS day_of_week,
    TO_CHAR(d, 'Day')                               AS day_name,
    CASE WHEN EXTRACT(MONTH FROM d) >= 9
         THEN EXTRACT(YEAR FROM d)::INT
         ELSE EXTRACT(YEAR FROM d)::INT - 1
    END                                              AS fiscal_year
FROM generate_series('2022-01-01'::DATE, '2026-12-31'::DATE, '1 day') AS d;

-- Checkpoint tests
SELECT fiscal_year FROM dwh.dim_date WHERE date_key = '2023-10-01'; -- expect 2023
SELECT fiscal_year FROM dwh.dim_date WHERE date_key = '2024-01-01'; -- expect 2023
SELECT MIN(date_key), MAX(date_key) FROM dwh.dim_date; -- expect 2022-01-01 .. 2026-12-31
