# load_promotion_program.py  (SRC-10, OneDrive, XLSX — multi-sheet, 1 sheet = 1 program)
import uuid
import time
import sys
sys.path.append('..')

from connectors.onedrive_connector import list_files_in_folder, download_file_as_bytes
from utils.file_parser import parse_file, list_sheet_names
from utils.db_utils import add_metadata, load_to_bronze, get_engine
from sqlalchemy import text

DRIVE_ID = 'your_onedrive_drive_id_here'
FOLDER_PATH = 'PromotionProgram'
TABLE_NAME = 'promotion_program'


def run():
    batch_id = str(uuid.uuid4())
    start = time.time()
    engine = get_engine()

    files = [f for f in list_files_in_folder(DRIVE_ID, FOLDER_PATH) if f['name'].endswith('.xlsx')]
    if not files:
        print('Không tìm thấy file promotion_program.xlsx')
        return

    f = files[0]
    total = 0
    try:
        raw_bytes = download_file_as_bytes(DRIVE_ID, f['id'])
        sheet_names = list_sheet_names(raw_bytes, f['name'])
        for sheet in sheet_names:
            df = parse_file(raw_bytes, f['name'], sheet_name=sheet)
            df['program_name'] = sheet  # tag each row with which program/sheet it came from
            df = add_metadata(df, f['name'], 'onedrive', batch_id)
            rows = load_to_bronze(df, TABLE_NAME, if_exists='append')
            total += rows
            print(f'  OK: {f["name"]} [{sheet}] — {rows} dòng')
        status, err = 'SUCCESS', None
    except Exception as e:
        print(f'  LỖI: {f["name"]} — {e}')
        status, err = 'FAILED', str(e)

    with engine.begin() as conn:
        conn.execute(text(
            'INSERT INTO raw.ingest_log (batch_id, source_name, source_file,'
            ' source_platform, rows_loaded, status, error_message, duration_sec)'
            ' VALUES (:bid, :sn, :sf, :sp, :rl, :st, :err, :dur)'
        ), dict(bid=batch_id, sn=TABLE_NAME, sf=f['name'], sp='onedrive',
                rl=total, st=status, err=err, dur=round(time.time() - start, 2)))


if __name__ == '__main__':
    run()
