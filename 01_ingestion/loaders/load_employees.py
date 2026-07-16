# load_employees.py  (SRC-07, OneDrive, XLSX — SCD2 handled later in Silver, Task 3.1.2)
# Bronze just appends every extract as-is; do NOT try to dedupe or version here.
import uuid
import time
import sys
sys.path.append('..')

from connectors.onedrive_connector import list_files_in_folder, download_file_as_bytes
from utils.file_parser import parse_file
from utils.db_utils import add_metadata, load_to_bronze, get_engine
from sqlalchemy import text

DRIVE_ID = 'your_onedrive_drive_id_here'
FOLDER_PATH = 'Employees'
TABLE_NAME = 'employee_master'


def run():
    batch_id = str(uuid.uuid4())
    start = time.time()
    engine = get_engine()

    files = [f for f in list_files_in_folder(DRIVE_ID, FOLDER_PATH) if f['name'].endswith('.xlsx')]
    if not files:
        print('Không tìm thấy file employee_master.xlsx')
        return

    f = files[0]
    try:
        raw_bytes = download_file_as_bytes(DRIVE_ID, f['id'])
        df = parse_file(raw_bytes, f['name'])
        df = add_metadata(df, f['name'], 'onedrive', batch_id)
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
        ), dict(bid=batch_id, sn=TABLE_NAME, sf=f['name'], sp='onedrive',
                rl=rows, st=status, err=err, dur=round(time.time() - start, 2)))


if __name__ == '__main__':
    run()
