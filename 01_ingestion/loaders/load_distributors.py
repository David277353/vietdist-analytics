# load_distributors.py — handles TWO sources:
#   SRC-05 distributor_orders  (Google Drive, XLSB, multi-file)
#   SRC-06 distributor_master  (Google Drive, CSV, single file)
import uuid
import time
import sys
sys.path.append('..')

from connectors.gdrive_connector import list_files_in_folder, download_file_as_bytes
from utils.file_parser import parse_file
from utils.db_utils import add_metadata, load_to_bronze, get_engine
from sqlalchemy import text

ORDERS_FOLDER_ID = 'your_gdrive_folder_id_here'
MASTER_FOLDER_ID = 'your_gdrive_folder_id_here'


def _log(engine, batch_id, start, table, filename, rows, status, err=None):
    with engine.begin() as conn:
        conn.execute(text(
            'INSERT INTO raw.ingest_log (batch_id, source_name, source_file,'
            ' source_platform, rows_loaded, status, error_message, duration_sec)'
            ' VALUES (:bid, :sn, :sf, :sp, :rl, :st, :err, :dur)'
        ), dict(bid=batch_id, sn=table, sf=filename, sp='google_drive',
                rl=rows, st=status, err=err, dur=round(time.time() - start, 2)))


def load_distributor_orders(engine, batch_id, start):
    """SRC-05: XLSB — requires pyxlsb (pip install pyxlsb)."""
    files = [f for f in list_files_in_folder(ORDERS_FOLDER_ID) if f['name'].endswith('.xlsb')]
    total = 0
    for f in files:
        try:
            raw_bytes = download_file_as_bytes(f['id'])
            df = parse_file(raw_bytes, f['name'])
            df = add_metadata(df, f['name'], 'google_drive', batch_id)
            rows = load_to_bronze(df, 'distributor_orders', if_exists='append')
            total += rows
            print(f'  OK: {f["name"]} — {rows} dòng')
            _log(engine, batch_id, start, 'distributor_orders', f['name'], rows, 'SUCCESS')
        except Exception as e:
            print(f'  LỖI: {f["name"]} — {e}')
            _log(engine, batch_id, start, 'distributor_orders', f['name'], 0, 'FAILED', str(e))
    return total


def load_distributor_master(engine, batch_id, start):
    """SRC-06: CSV, single file."""
    files = [f for f in list_files_in_folder(MASTER_FOLDER_ID) if f['name'].endswith('.csv')]
    if not files:
        print('Không tìm thấy distributor_master.csv')
        return 0
    f = files[0]
    try:
        raw_bytes = download_file_as_bytes(f['id'])
        df = parse_file(raw_bytes, f['name'])
        df = add_metadata(df, f['name'], 'google_drive', batch_id)
        rows = load_to_bronze(df, 'distributor_master', if_exists='append')
        print(f'  OK: {f["name"]} — {rows} dòng')
        _log(engine, batch_id, start, 'distributor_master', f['name'], rows, 'SUCCESS')
        return rows
    except Exception as e:
        print(f'  LỖI: {f["name"]} — {e}')
        _log(engine, batch_id, start, 'distributor_master', f['name'], 0, 'FAILED', str(e))
        return 0


def run():
    batch_id = str(uuid.uuid4())
    start = time.time()
    engine = get_engine()
    total = load_distributor_orders(engine, batch_id, start)
    total += load_distributor_master(engine, batch_id, start)
    print(f'Tổng cộng: {total} dòng đã load')


if __name__ == '__main__':
    run()
