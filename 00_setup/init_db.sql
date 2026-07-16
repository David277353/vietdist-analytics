-- Then connect to vietdist_dw and run the rest of this file:
CREATE SCHEMA IF NOT EXISTS raw;      -- Bronze layer
CREATE SCHEMA IF NOT EXISTS staging;  -- Silver layer
CREATE SCHEMA IF NOT EXISTS dwh;      -- Gold layer

-- Sanity check: expect 3 rows
SELECT schema_name FROM information_schema.schemata
WHERE schema_name IN ('raw', 'staging', 'dwh');

-- ---------------------------------------------------------------------
-- Ingestion log table (Subtask 1.3.2) — tracks every pipeline run
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.ingest_log (
    log_id          SERIAL PRIMARY KEY,
    batch_id        UUID NOT NULL,
    source_name     TEXT NOT NULL,      -- e.g. 'sales_transactions'
    source_file     TEXT,               -- original file name
    source_platform TEXT,               -- 'google_drive' | 'onedrive'
    rows_loaded     INTEGER,
    status          TEXT NOT NULL,      -- 'SUCCESS' | 'FAILED'
    error_message   TEXT,
    duration_sec    NUMERIC,
    started_at      TIMESTAMP DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- Sales target versioning tables (Subtask 1.4.1)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.sales_target_files (
    id              SERIAL PRIMARY KEY,
    version_label   TEXT NOT NULL,      -- 'v1', 'v2', 'v3'...
    source_file     TEXT NOT NULL,
    sheet_name      TEXT,
    ingested_at     TIMESTAMP DEFAULT NOW(),
    batch_id        UUID
);

CREATE TABLE IF NOT EXISTS raw.sales_targets_raw (
    id              SERIAL PRIMARY KEY,
    version_label   TEXT NOT NULL,
    employee_code   TEXT,
    month_col       TEXT,               -- 'T1'..'T12' only, no 'Tổng' rows
    target_value    TEXT,               -- TEXT in bronze, cast later in staging
    source_file     TEXT,
    _ingested_at    TIMESTAMP DEFAULT NOW(),
    _batch_id       UUID
);
