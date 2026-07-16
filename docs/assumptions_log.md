# Assumptions Log

Record every assumption made when the source data is ambiguous.
Format: Date — Area — Assumption — Why.

2026-07-08 — sales_transactions grain — The natural key of a sales line item is
**(order_id, product_id)**, not order_id alone — because raw has 119,101 rows but only
50,000 distinct order_id values (~2.4 lines per order). fact_sales inherits this grain:
1 row per order line item. Revisit if a true line-item ID ever appears in the source.

2026-07-08 — deduplication rule — When the same natural key is loaded more than once,
the row with the **latest `_ingested_at`** wins (`DISTINCT ON ... ORDER BY _ingested_at DESC`)
— because re-loads should overwrite, not duplicate.

2026-07-08 — sales_target_plan versioning — Version effectivity is read **directly from the
source columns** (`plan_version`, `effective_from`, `effective_to`, `year`, `month`), not
inferred from filenames as the brief's wide T1–T12 layout suggested — because the actual
sample file already comes long-format with explicit effectivity columns. "Latest" per
employee+year+month = most recent `effective_from` (tie-break: `version_date`), flagged
`is_latest`. Marts always use `is_latest = TRUE`.

2026-07-09 — employee SCD2 — dim_employees derives SCD2 windows from the source's own
`version` + `effective_date` + `resign_date` columns rather than from load timestamps —
because employee_master already tracks its own history (114 rows for fewer employees).
`effective_to` = day before the next version's `effective_date`; for the last version it is
`resign_date` if resigned, else NULL (open-ended). Rows with no `effective_date` are excluded
(cannot be sequenced). Exactly one `is_current = TRUE` per employee (verified: 0 violations).

2026-07-09 — employee `version` datatype — `version` is text ('v1', 'v2'), not numeric —
an INT cast failed at staging. Same applies to `territory_mapping.version`. Kept as TEXT.

2026-07-09 — distributor SCD2 — True SCD2 is **not possible** for dim_distributors: the
source is a single current snapshot with no version/effective_date columns. Built an
SCD2-*shaped* table (effective_from = join_date, effective_to = NULL, is_current = TRUE)
so fact joins won't need rework if periodic snapshots arrive later.

2026-07-09 — fiscal year — FY starts **September**: month >= 9 → fiscal_year = calendar
year, else calendar year − 1 — chosen to satisfy the brief's checkpoints
(2023-10-01 → FY2023; 2024-01-01 → FY2023). Adjust the MONTH() threshold in
gold/01_dim_date.sql if the business defines FY differently.

2026-07-09 — dim_date range — Static calendar 2022-01-01 to 2026-12-31, covering all
observed transaction dates plus headroom.

2026-07-10 — fact_sales keys — fact_sales keeps **natural keys** (order_id, customer_id,
product_id, employee_id) alongside surrogate keys (customer_sk, product_sk, employee_sk) —
natural keys make mart queries and debugging much simpler; surrogate keys support proper
dimensional joins in Power BI. Employee join is point-in-time: order_date BETWEEN
effective_from AND COALESCE(effective_to, '9999-12-31'). Verified 0 orphans on all three SKs.

2026-07-10 — mart_distributor_performance coverage — Inner join to distributor orders means
distributors with **no orders are excluded** (125 of 138 appear). Acceptable for a
performance mart; switch to LEFT JOIN from dim_distributors if "silent" distributors must
be visible.

2026-07-10 — ontime_delivery parsing — `ontime_delivery` values treated as true when in
('Y', 'true', 'True', '1'); everything else counts as not on time.

2026-07-10 — targets vs actuals — Achievement % is low across the sample (roughly 29–73%
in spot checks). Treated as a property of the sample data (ambitious targets), not a
pipeline defect — actuals reconcile exactly with raw (119,101 rows end-to-end).
