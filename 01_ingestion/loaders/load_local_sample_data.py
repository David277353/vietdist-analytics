"""
load_local_sample_data.py

Loads ALL 10 sample files straight from your local
"Raw Data/Data Materials/VietDist_SampleData" folder into raw.* tables —
no Google Drive / OneDrive connector needed. Use this to get Bronze populated
and test the rest of the pipeline right now; swap in the real cloud connectors
later once your files actually live on Drive/OneDrive.

Run from 01_ingestion/loaders/:
    python load_local_sample_data.py
"""
import glob
import os
import sys
import time
import uuid

sys.path.append('..')
from utils.file_parser import parse_file, list_sheet_names
from utils.db_utils import add_metadata, load_to_bronze, get_engine
from sqlalchemy import text

# Adjust this if your OneDrive path differs
SAMPLE_DATA_DIR = (
    r"C:\Users\Owner\OneDrive\Documentos\UniGap Data Analyst\Python"
    r"\Final Project\Raw Data\Data Materials\VietDist_SampleData"
)

# SRC prefix -> raw table name
SRC_TABLE_MAP = {
    'SRC01': 'sales_transactions',
    'SRC02': 'sales_target_plan_raw',   # simplified single-file load; versioning handled in Task 1.4
    'SRC03': 'customer_master',
    'SRC04': 'product_master',
    'SRC05': 'distributor_orders',
    'SRC06': 'distributor_master',
    'SRC07': 'employee_master',
    'SRC08': 'territory_mapping',
    'SRC09': 'return_transactions',
    'SRC10': 'promotion_program',
}

# Sources known to have multiple sheets worth keeping separately
MULTI_SHEET_SOURCES = {'SRC10'}


def _log(engine, batch_id, start, table, filename, rows, status, err=None):
    with engine.begin() as conn:
        conn.execute(text(
            'INSERT INTO raw.ingest_log (batch_id, source_name, source_file,'
            ' source_platform, rows_loaded, status, error_message, duration_sec)'
            ' VALUES (:bid, :sn, :sf, :sp, :rl, :st, :err, :dur)'
        ), dict(bid=batch_id, sn=table, sf=filename, sp='local',
                rl=rows, st=status, err=err, dur=round(time.time() - start, 2)))


def run():
    batch_id = str(uuid.uuid4())
    engine = get_engine()

    files = sorted(glob.glob(os.path.join(SAMPLE_DATA_DIR, '*')))
    if not files:
        print(f'Không tìm thấy file nào trong: {SAMPLE_DATA_DIR}')
        return

    for path in files:
        filename = os.path.basename(path)
        prefix = filename.split('_')[0]  # e.g. 'SRC01'
        table = SRC_TABLE_MAP.get(prefix)
        if table is None:
            print(f'  BỎ QUA (không map được): {filename}')
            continue

        start = time.time()
        try:
            with open(path, 'rb') as fh:
                raw_bytes = fh.read()

            if prefix in MULTI_SHEET_SOURCES:
                sheet_names = list_sheet_names(raw_bytes, filename)
                total_rows = 0
                for sheet in sheet_names:
                    df = parse_file(raw_bytes, filename, sheet_name=sheet)
                    if prefix == 'SRC10':
                        df['program_name'] = sheet
                    df = add_metadata(df, filename, 'local', batch_id)
                    rows = load_to_bronze(df, table, if_exists='append')
                    total_rows += rows
                    print(f'  OK: {filename} [{sheet}] — {rows} dòng -> raw.{table}')
                rows = total_rows
            else:
                df = parse_file(raw_bytes, filename)
                df = add_metadata(df, filename, 'local', batch_id)
                rows = load_to_bronze(df, table, if_exists='append')
                print(f'  OK: {filename} — {rows} dòng -> raw.{table}')

            _log(engine, batch_id, start, table, filename, rows, 'SUCCESS')
        except Exception as e:
            print(f'  LỖI: {filename} — {e}')
            _log(engine, batch_id, start, table, filename, 0, 'FAILED', str(e))

    print('Hoàn tất load dữ liệu mẫu vào Bronze (raw schema).')


if __name__ == '__main__':
    run()
