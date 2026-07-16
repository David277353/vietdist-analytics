# Data Dictionary

One section per table. Bronze (`raw.*`) lands everything as TEXT plus lineage columns
(`_source_file`, `_ingested_at`); types below are the **Silver (staging.*) cast types**,
which carry through to Gold. Verified against the live schema on 2026-07-10.

---

## Layer 1 — Bronze → Silver (staging.*)

### staging.stg_sales_transactions (from raw.sales_transactions, SRC-01) — 119,101 rows
Grain: 1 row per **(order_id, product_id)** line item.

| Column | Type | Description | Notes |
|---|---|---|---|
| order_id | TEXT | Order-level ID | NOT unique alone: ~2.4 lines/order (50,000 distinct) |
| order_date | DATE | Order date | Part of dedup/quality filter |
| order_month / order_quarter / order_year | INT | Pre-derived date parts from source | Redundant with dim_date; kept for traceability |
| customer_id | TEXT | FK → stg_customers | |
| region / province / channel | TEXT | Denormalized geography & channel | |
| employee_id | TEXT | Salesperson, FK → stg_employees | |
| product_id | TEXT | FK → stg_products | Grain component |
| product_category | TEXT | Denormalized category | |
| quantity | NUMERIC | Units sold | |
| unit_price | NUMERIC | Price per unit (VND) | |
| discount_pct / discount_amount | NUMERIC | Line discount | |
| gross_amount / net_amount | NUMERIC | Line totals (VND); net = gross − discount | net_amount feeds actual_sales |
| delivery_status / payment_method / payment_status | TEXT | Fulfilment & payment state | |

### staging.stg_customers (from raw.customer_master, SRC-03) — 2,000 rows
| Column | Type | Description |
|---|---|---|
| customer_id | TEXT | PK |
| customer_name / customer_type / channel | TEXT | Identity & segment |
| province / region / address / phone / tax_code | TEXT | Location & contact |
| join_date | DATE | Onboarding date |
| credit_limit | NUMERIC | VND |
| status | TEXT | Active/inactive |

### staging.stg_products (from raw.product_master, SRC-04) — 100 rows
| Column | Type | Description |
|---|---|---|
| product_id | TEXT | PK |
| product_name / category / sub_category / unit | TEXT | Identity & hierarchy |
| unit_price / cost_price | NUMERIC | List price / cost (VND) |
| weight_gram | NUMERIC | Unit weight |
| status | TEXT | Active/discontinued |
| launch_date | DATE | |

### staging.stg_employees (from raw.employee_master, SRC-07) — 114 version rows
Source tracks its own history: one row per employee **version**. Not deduped.

| Column | Type | Description |
|---|---|---|
| employee_id | TEXT | Natural key (repeats across versions) |
| full_name / gender / date_of_birth / join_date | TEXT·DATE | Person attributes |
| "position" / region / team / email / phone / status | TEXT | Role attributes (change across versions) |
| version | TEXT | 'v1', 'v2', … (text, not numeric) |
| effective_date | DATE | Version start; required for SCD2 sequencing |
| resign_date | DATE | Populated on final version if resigned |
| transfer_note | TEXT | Free-text change reason |

### staging.stg_distributor_master (SRC-06) — 138 rows / stg_distributor_orders (SRC-05) — 35,945 rows
**stg_distributor_master** — single current snapshot, no history columns.

| Column | Type | Description |
|---|---|---|
| distributor_id | TEXT | PK |
| distributor_name / tier / channel / province / region | TEXT | Identity & segment |
| contact_person / phone / email / tax_code | TEXT | Contact |
| join_date | DATE | |
| credit_limit | NUMERIC | VND |
| status | TEXT | |
| assigned_supervisor_id | TEXT | FK → employees |

**stg_distributor_orders** — grain: 1 row per order_id.

| Column | Type | Description |
|---|---|---|
| order_id | TEXT | PK |
| order_date | DATE | + order_month / order_quarter (INT) |
| distributor_id | TEXT | FK → stg_distributor_master |
| region / channel / product_id / product_category | TEXT | |
| qty_ordered / qty_delivered | NUMERIC | |
| fill_rate_pct | NUMERIC | qty_delivered ÷ qty_ordered × 100 (source-provided) |
| unit_price_list / distributor_price | NUMERIC | VND |
| gross_amount / delivered_amount | NUMERIC | VND |
| expected_delivery_date / actual_delivery_date | DATE | |
| ontime_delivery | TEXT | 'Y'/'true'/'1' variants → parsed in mart |
| delivery_status / payment_terms | TEXT | |

### staging.stg_sales_targets_versioned (from raw.sales_target_plan_raw, SRC-02) — 1,332 rows
Long-format source (NOT the wide T1–T12 layout in the brief). Grain: employee × year × month × plan_version.

| Column | Type | Description |
|---|---|---|
| employee_id / employee_name / region / team | TEXT | Target owner |
| plan_version | TEXT | Source-provided version label |
| version_date / effective_from / effective_to | DATE | Version effectivity from source |
| year / month | INT | Target period |
| target_revenue / target_quantity / target_new_customers | NUMERIC | Monthly targets |
| is_latest | BOOL | Derived: TRUE for the most recent effective_from per employee+year+month (exactly 1 per combo) |

### staging.stg_territory_mapping (SRC-08) — 1,843 rows
territory_id, employee_id, customer_id, region, team (TEXT); effective_date, expiry_date (DATE); version (TEXT 'v1'). territory_id not unique — assignment rows kept as-is.

### staging.stg_promotion_program (SRC-10) — 40 rows
promotion_id (PK), promotion_name, promotion_type, target_channel, target_region, applicable_products, status, created_by, program_name (sheet tag) — TEXT; start_date, end_date — DATE; discount_pct, min_order_quantity, budget_vnd, actual_cost_vnd — NUMERIC.

### staging.stg_return_transactions (SRC-09) — 3,665 rows
return_id (PK), original_order_id, customer_id, employee_id, product_id, region, province, return_reason, status — TEXT; return_date — DATE; return_month — INT; return_quantity, unit_price, return_amount — NUMERIC.

---

## Layer 2 — Gold (dwh.*)

### dwh.dim_date — 1,826 rows (2022-01-01 → 2026-12-31)
| Column | Type | Description |
|---|---|---|
| date_key | DATE | PK |
| year / quarter / month / week_of_year / day_of_month / day_of_week | INT | Calendar parts |
| month_name / day_name | TEXT | |
| fiscal_year | INT | FY starts September: month ≥ 9 → year, else year − 1 |

### dwh.dim_customers (SCD1) — 2,000 rows / dwh.dim_products (SCD1) — 100 rows
All stg columns + surrogate key `customer_sk` / `product_sk` (ROW_NUMBER). Overwrite on rebuild, no history.

### dwh.dim_employees (SCD2) — 1 row per employee version
| Column | Type | Description |
|---|---|---|
| employee_sk | BIGINT | Surrogate PK (per version) |
| employee_id | TEXT | Natural key |
| full_name … transfer-level attributes | | As in staging |
| effective_from | DATE | = source effective_date |
| effective_to | DATE | Day before next version's effective_from; resign_date on last version if resigned; NULL if open |
| is_current | BOOL | Exactly 1 TRUE per employee |

### dwh.dim_distributors (SCD2-shaped) — 138 rows
All snapshot columns + distributor_sk; effective_from = join_date, effective_to = NULL, is_current = TRUE (no source history — see assumptions log).

### dwh.fact_sales — 119,101 rows (grain: order line item)
| Column | Type | Description |
|---|---|---|
| order_id, product_id, customer_id, employee_id | TEXT | Natural keys |
| date_key | DATE | = order_date, FK → dim_date |
| customer_sk / product_sk / employee_sk | BIGINT | FKs → dims; employee join is point-in-time on date_key. 0 orphans verified |
| quantity, unit_price, discount_pct, discount_amount, gross_amount, net_amount | NUMERIC | Measures |
| region, province, channel, delivery_status, payment_method, payment_status | TEXT | Degenerate attributes |

### dwh.fact_targets — 1,332 rows
stg_sales_targets_versioned minus lineage columns; filter `is_latest` for current targets.

### dwh.fact_returns — 3,665 rows
stg_return_transactions with return_date renamed to date_key (FK → dim_date).

### dwh.mart_sales_vs_target — grain: employee × year × month
| Column | Type | Description |
|---|---|---|
| employee_id | TEXT | |
| year / month | INT | |
| actual_sales | NUMERIC | SUM(fact_sales.net_amount) |
| target_revenue | NUMERIC | From fact_targets WHERE is_latest |
| variance_abs | NUMERIC | actual − target |
| achievement_pct | NUMERIC | 100 × actual ÷ target (NULL-safe) |

### dwh.mart_distributor_performance — 125 rows (distributors with ≥1 order)
| Column | Type | Description |
|---|---|---|
| distributor_id / distributor_name / tier / channel | TEXT | |
| order_count | BIGINT | COUNT of orders |
| total_gross_amount / total_delivered_amount | NUMERIC | VND |
| avg_fill_rate_pct | NUMERIC | Mean of source fill_rate_pct |
| ontime_rate | NUMERIC | Share of orders with ontime_delivery ∈ ('Y','true','True','1') |
