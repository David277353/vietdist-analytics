# load_sales_transactions.py  (SRC-01, Google Drive, CSV, multi-file by day)
import uuid
import time
import sys
sys.path.append('..')

from connectors.gdrive_connector import list_files_in_folder, download_file_as_bytes
from utils.file_parser import parse_file
from utils.db_utils import add_metadata, load_to_bronze, get_engine
from sqlalchemy import text

FOLDER_ID = 'your_gdrive_folder_id_here'  # from the folder's Drive URL
TABLE_NAME = 'sales_transactions'


def run():
    batch_id = str(uuid.uuid4())
    start = time.time()
    engine = get_engine()

    files = list_files_in_folder(FOLDER_ID)
    print(f'Tìm thấy {len(files)} file(s) trong folder')

    total_loaded = 0
    for f in files:
        if not f['name'].endswith('.csv'):
            continue
        try:
            raw_bytes = download_file_as_bytes(f['id'])
            df = parse_file(raw_bytes, f['name'])
            df = add_metadata(df, f['name'], 'google_drive', batch_id)
            rows = load_to_bronze(df, TABLE_NAME, if_exists='append')
            total_loaded += rows
            print(f'  OK: {f["name"]} — {rows} dòng')

            with engine.begin() as conn:
                conn.execute(text(
                    'INSERT INTO raw.ingest_log (batch_id, source_name, source_file,'
                    ' source_platform, rows_loaded, status, duration_sec)'
                    ' VALUES (:bid, :sn, :sf, :sp, :rl, :st, :dur)'
                ), dict(bid=batch_id, sn=TABLE_NAME, sf=f['name'],
                        sp='google_drive', rl=rows, st='SUCCESS',
                        dur=round(time.time() - start, 2)))
        except Exception as e:
            print(f'  LỖI: {f["name"]} — {e}')
            with engine.begin() as conn:
                conn.execute(text(
                    'INSERT INTO raw.ingest_log (batch_id, source_name, source_file,'
                    ' source_platform, rows_loaded, status, error_message, duration_sec)'
                    ' VALUES (:bid, :sn, :sf, :sp, :rl, :st, :err, :dur)'
                ), dict(bid=batch_id, sn=TABLE_NAME, sf=f['name'],
                        sp='google_drive', rl=0, st='FAILED', err=str(e),
                        dur=round(time.time() - start, 2)))

    print(f'Tổng cộng: {total_loaded} dòng đã load')


if __name__ == '__main__':
    run()
