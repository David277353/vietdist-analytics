# VietDist Analytics — Project Checklist

Medallion pipeline: Google Drive / OneDrive → PostgreSQL (raw → staging → dwh) → Power BI.

Work top to bottom. Don't skip a checkpoint — each phase builds on the last.

## Phase 0 — Environment Setup
- [ ] Python 3.11+, PostgreSQL 16, VS Code, Git installed
- [ ] Virtual env created, `pip install -r 00_setup/requirements.txt`
- [ ] `vietdist_dw` database created, schemas `raw` / `staging` / `dwh` exist (run `00_setup/init_db.sql`)
- [ ] `.env` created from `.env.example`, added to `.gitignore` along with `credentials/`

## Phase 1 — Bronze Layer
- [ ] Google Drive service account working — `list_files_in_folder()` returns real files
- [ ] OneDrive app registration working — `get_access_token()` returns a token
- [ ] All 10 loaders in `01_ingestion/loaders/` run without error and populate `raw.*`
- [ ] `raw.ingest_log` has SUCCESS rows for every source
- [ ] Sales target versioning (`load_sales_targets.py`) keeps every version — no overwrites
- [ ] `raw.sales_target_files` shows v1, v2 (and v3 if present) with no data loss

## Phase 2 — Silver Layer
- [ ] `docs/data_issues.md` filled in for all 10 raw tables
- [ ] All `staging.stg_*` models created (`02_sql_analytics/staging/`)
- [ ] Not-null + unique tests pass (0 failures) on every PK
- [ ] `stg_sales_targets_versioned` — every employee x month has exactly one `is_latest = TRUE` row

## Phase 3 — Gold Layer
- [ ] `dim_date` covers 2022-2026, fiscal_year logic verified against checkpoints
- [ ] `dim_employees` SCD2 implemented — employees who changed region have 2+ rows, exactly one `is_current`
- [ ] `dim_customers`, `dim_products` (SCD1), `dim_distributors` (SCD2) built
- [ ] `fact_sales`, `fact_targets`, `fact_returns` built, orphan-key checks pass
- [ ] `mart_sales_vs_target` and `mart_distributor_performance` built

## Phase 4 — Power BI (not yet scaffolded)
- [ ] Connect Power BI Desktop to `dwh` schema
- [ ] Build `03_power_bi/vietdist_dashboard.pbix`

## Where things live
- `00_setup/` — installs, env template, DB init script
- `01_ingestion/` — connectors, loaders, parsers (Bronze)
- `02_sql_analytics/staging/` — Silver models, `gold/` — Gold dim/fact/mart, `ad_hoc_queries.sql` — scratch
- `docs/` — data dictionary, assumptions log, data issues log (fill these in as you go — a reviewer will read them)

## Notes
- Every SQL file under `02_sql_analytics/` is a **starting template**, not a finished solution —
  column names, folder paths, and file-naming assumptions are marked `TODO` and must match your
  actual source files.
- The two hardest parts are flagged in the brief and in the code: sales target versioning
  (`load_sales_targets.py` + `staging/06_stg_sales_targets_versioned.sql`) and employee SCD2
  (`gold/02_dim_employees_scd2.sql`). Do these last, after the simpler sources are working end to end.
