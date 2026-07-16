# Data Issues Log (Subtask 2.1.1)

For each raw.* table: total row count, key-column quality, duplicates, and how it was
handled in Silver (staging.*). All counts verified against `raw.ingest_log` and staging
tests on 2026-07-10.

## raw.sales_transactions (SRC-01)
- Total rows: **119,101**
- Key columns: `order_id`, `order_date`, `product_id` — 0 nulls/blanks on all three (verified with `COUNT(*) FILTER (WHERE ... IS NULL OR ... = '')`).
- **Issue — grain:** `order_id` is an *order-level* ID, not a line-item ID. Only **50,000 distinct order_id** values across 119,101 rows (~2.4 product lines per order). An initial dedup on `order_id` alone would have destroyed ~69,000 legitimate line items.
- Duplicates on the true grain `(order_id, product_id)`: 0.
- Plan: Silver dedupes with `DISTINCT ON (order_id, product_id)`, keeping the most recent `_ingested_at` per pair. Staging row count = 119,101 (exact match with raw — no data lost).

## raw.customer_master (SRC-03)
- Total rows: **2,000**; 0 blank `customer_id`; 0 duplicate `customer_id`.
- No issues found. Silver: `DISTINCT ON (customer_id)`, latest `_ingested_at` wins. 2,000 rows out.

## raw.product_master (SRC-04)
- Total rows: **100**; 0 blank `product_id`; 0 duplicates.
- No issues found. Silver: `DISTINCT ON (product_id)`. 100 rows out.

## raw.employee_master (SRC-07)
- Total rows: **114** for fewer distinct employees — the source carries its own history: each row has `version` ('v1', 'v2', …), `effective_date`, `resign_date`, `transfer_note`.
- **Issue — type:** `version` looks numeric but is text ('v1'), an `::INT` cast failed. Fixed: kept as TEXT.
- Plan: Silver keeps *every* version row (no dedup by employee_id) so Gold can build SCD2 directly from `effective_date`. Rows without `effective_date` are excluded from dim_employees (cannot be sequenced).

## raw.distributor_master (SRC-06) / raw.distributor_orders (SRC-05)
- distributor_master: **138** rows; single current snapshot — **no version/effective_date columns**, so no change history is available from this source (see assumptions log: SCD2-shaped but open-ended).
- distributor_orders: **35,945** rows; 0 duplicate `order_id`.
- Note: only **125** of 138 distributors appear in `mart_distributor_performance` — 13 distributors have no orders in the sample period (inner join drops them; acceptable for a performance mart).

## raw.sales_target_plan_raw (SRC-02)
- Total rows: **1,332**.
- **Issue — layout differs from brief:** the brief describes a wide T1–T12 monthly layout with version embedded in filenames; the actual source is already *long-format* with explicit `plan_version`, `version_date`, `effective_from`, `effective_to`, `year`, `month` columns. Versioning logic was simplified accordingly.
- Current sample has exactly **1 version per employee+year+month** (verified: every combo has exactly one `is_latest = TRUE` row). Multiple revisions will be handled automatically by the `ROW_NUMBER() OVER (... ORDER BY effective_from DESC)` logic when they appear.

## raw.territory_mapping (SRC-08)
- Total rows: **1,843**.
- **Issue — type:** `version` is text ('v1'), same as employee_master; `::INT` cast removed preemptively.
- `territory_id` is not unique across rows (mapping rows per employee/customer/period) — kept all rows in Silver.

## raw.promotion_program (SRC-10)
- Total rows: **40** (multi-sheet Excel; sheet name captured as `program_name` at load time).
- 0 duplicate `promotion_id`. No issues.

## raw.return_transactions (SRC-09)
- Total rows: **3,665**; 0 duplicate `return_id`. No issues.
- Carried to `dwh.fact_returns` 1:1 (3,665 rows).

## Cross-cutting observations
- All Bronze columns land as TEXT; Silver applies `NULLIF(x,'')::DATE/NUMERIC/INT` casts. Two text-vs-int surprises (`version` columns) were the only cast failures.
- Referential integrity after Gold build: **0 orphans** in `dwh.fact_sales` (customer_sk / product_sk / employee_sk all fully matched, including the point-in-time employee join).
- **Business-level observation:** targets consistently exceed actuals — achievement_pct in `mart_sales_vs_target` ranges roughly 29–73% in spot checks. Not a data error; sample targets appear ambitious relative to sales. Expect predominantly below-target visuals in Power BI.
