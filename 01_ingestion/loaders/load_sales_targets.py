# load_sales_targets.py  (SRC-02, OneDrive, XLSX — MULTI-VERSION, hardest task, Task 1.4)
#
# Rules to respect:
#   - A version can be a whole separate file OR a sheet within one file.
#   - NEVER overwrite an earlier version; every version is kept forever.
#   - Skip 'Tổng' (total) rows — only T1..T12 month columns go into sales_targets_raw.
#   - Every version + sheet gets one row in raw.sales_target_files.
#   - Melt wide (T1..T12 as columns) into long format for raw.sales_targets_raw.
import uuid
import time
import sys
sys.path.append('..')

import pandas as pd
from connectors.onedrive_connector import list_files_in_folder, download_file_as_bytes
from utils.file_parser import parse_file, list_sheet_names
from utils.db_utils import get_engine
from sqlalchemy import text

DRIVE_ID = 'your_onedrive_drive_id_here'
FOLDER_PATH = 'SalesTargets'

MONTH_COLS = [f'T{i}' for i in range(1, 13)]
EXCLUDE_ROW_MARKERS = ['Tổng', 'TONG', 'TOTAL']  # rows to drop, case-insensitive match


def _version_label_from_filename(filename: str) -> str:
    """
    TODO: adjust this to match your real file naming convention.
    Examples this handles: sales_target_v1.xlsx, sales_target_2024_v2.xlsx
    """
    lower = filename.lower()
    for token in ['v3', 'v2', 'v1']:
        if token in lower:
            return token
    return 'v1'  # fallback — flag in docs/assumptions_log.md if this fires


def _melt_to_long(df: pd.DataFrame, version_label: str, employee_col: str = 'employee_code') -> pd.DataFrame:
    """Wide (T1..T12 as columns) -> long (one row per employee x month)."""
    # Drop 'Tổng' rows if a text column contains them
    mask = df.apply(lambda r: not any(str(v).strip() in EXCLUDE_ROW_MARKERS for v in r), axis=1)
    df = df[mask]

    id_vars = [c for c in df.columns if c not in MONTH_COLS]
    present_month_cols = [c for c in MONTH_COLS if c in df.columns]
    long_df = df.melt(id_vars=id_vars, value_vars=present_month_cols,
                       var_name='month_col', value_name='target_value')
    long_df['version_label'] = version_label
    return long_df


def run():
    batch_id = str(uuid.uuid4())
    start = time.time()
    engine = get_engine()

    files = [f for f in list_files_in_folder(DRIVE_ID, FOLDER_PATH) if f['name'].endswith('.xlsx')]
    if not files:
        print('Không tìm thấy file sales_target_plan.xlsx')
        return

    for f in files:
        version_label = _version_label_from_filename(f['name'])
        try:
            raw_bytes = download_file_as_bytes(DRIVE_ID, f['id'])
            sheet_names = list_sheet_names(raw_bytes, f['name'])

            # Case A: one version per file (single relevant sheet)
            # Case B: one file, multiple sheets = multiple versions
            # TODO: decide which case applies to your actual files and adjust the loop below.
            for sheet in sheet_names:
                df = parse_file(raw_bytes, f['name'], sheet_name=sheet)
                sheet_version = version_label if len(sheet_names) == 1 else sheet

                long_df = _melt_to_long(df, sheet_version)
                long_df['source_file'] = f['name']
                long_df['_batch_id'] = batch_id

                long_df.to_sql('sales_targets_raw', engine, schema='raw',
                                if_exists='append', index=False)

                with engine.begin() as conn:
                    conn.execute(text(
                        'INSERT INTO raw.sales_target_files'
                        ' (version_label, source_file, sheet_name, batch_id)'
                        ' VALUES (:v, :sf, :sh, :bid)'
                    ), dict(v=sheet_version, sf=f['name'], sh=sheet, bid=batch_id))

                print(f'  OK: {f["name"]} [{sheet}] -> version {sheet_version}, {len(long_df)} dòng')

            status, err, rows = 'SUCCESS', None, len(sheet_names)
        except Exception as e:
            print(f'  LỖI: {f["name"]} — {e}')
            status, err, rows = 'FAILED', str(e), 0

        with engine.begin() as conn:
            conn.execute(text(
                'INSERT INTO raw.ingest_log (batch_id, source_name, source_file,'
                ' source_platform, rows_loaded, status, error_message, duration_sec)'
                ' VALUES (:bid, :sn, :sf, :sp, :rl, :st, :err, :dur)'
            ), dict(bid=batch_id, sn='sales_target_plan', sf=f['name'], sp='onedrive',
                    rl=rows, st=status, err=err, dur=round(time.time() - start, 2)))


if __name__ == '__main__':
    run()
