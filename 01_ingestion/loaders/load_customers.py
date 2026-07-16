# load_customers.py  (SRC-03, Google Drive, CSV, single file — start here, it's the simplest)
import uuid
import time
import sys
sys.path.append('..')

from connectors.gdrive_connector import list_files_in_folder, download_file_as_bytes
from utils.file_parser import parse_file
from utils.db_utils import add_metadata, load_to_bronze, get_engine
from sqlalchemy import text

FOLDER_ID = 'your_gdrive_folder_id_here'
TABLE_NAME = 'customer_master'


def run():
    batch_id = str(uuid.uuid4())
    start = time.time()
    engine = get_engine()

    files = [f for f in list_files_in_folder(FOLDER_ID) if f['name'].endswith('.csv')]
    if not files:
        print('Không tìm thấy file customer_master.csv trong folder')
        return

    f = files[0]  # single file, always take the latest/only one
    try:
        raw_bytes = download_file_as_bytes(f['id'])
        df = parse_file(raw_bytes, f['name'])
        df = add_metadata(df, f['name'], 'google_drive', batch_id)
        # Bronze = append-only history; if you want "latest snapshot only" behavior,
        # truncate before loading instead — decide and note it in docs/assumptions_log.md
        rows = load_to_bronze(df, TABLE_NAME, if_exists='append')
        print(f'  OK: {f["name"]} — {rows} dòng')
        status, err = 'SUCCESS', None
    except Exception as e:
        rows = 0
        print(f'  LỖI: {f["name"]} — {e}')
        status, err = 'FAILED', str(e)

    with engine.begin() as conn:
        conn.execute(text(
            'INSERT INTO raw.ingest_log (batch_id, source_name, source_file,'
            ' source_platform, rows_loaded, status, error_message, duration_sec)'
            ' VALUES (:bid, :sn, :sf, :sp, :rl, :st, :err, :dur)'
        ), dict(bid=batch_id, sn=TABLE_NAME, sf=f['name'], sp='google_drive',
                rl=rows, st=status, err=err, dur=round(time.time() - start, 2)))


if __name__ == '__main__':
    run()
