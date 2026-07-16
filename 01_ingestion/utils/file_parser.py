"""
File parser (Subtask 1.1.3) — reads CSV, XLSX, XLSM, XLSB into a pandas DataFrame.

Notes:
- XLSB is binary Excel — requires `pip install pyxlsb`, engine='pyxlsb'.
- XLSM (macro-enabled) reads fine with openpyxl; macros are silently ignored (expected).
- Always eyeball the file in Excel first to confirm header row and sheet name
  before trusting the defaults below.
"""
import io
import pandas as pd


def parse_file(raw_bytes: bytes, filename: str, sheet_name=0, header: int = 0) -> pd.DataFrame:
    """Dispatch to the right pandas reader based on file extension."""
    name = filename.lower()
    buf = io.BytesIO(raw_bytes)

    if name.endswith('.csv'):
        # utf-8-sig handles a possible BOM in Vietnamese CSV exports;
        # fall back to a couple of common encodings if that fails.
        for enc in ('utf-8-sig', 'utf-8', 'cp1258', 'latin1'):
            try:
                buf.seek(0)
                return pd.read_csv(buf, encoding=enc)
            except (UnicodeDecodeError, UnicodeError):
                continue
        raise ValueError(f'Could not decode CSV file: {filename}')

    if name.endswith('.xlsx') or name.endswith('.xlsm'):
        return pd.read_excel(buf, sheet_name=sheet_name, header=header, engine='openpyxl')

    if name.endswith('.xlsb'):
        return pd.read_excel(buf, sheet_name=sheet_name, header=header, engine='pyxlsb')

    if name.endswith('.xls'):
        return pd.read_excel(buf, sheet_name=sheet_name, header=header, engine='xlrd')

    raise ValueError(f'Unsupported file type: {filename}')


def list_sheet_names(raw_bytes: bytes, filename: str) -> list[str]:
    """Useful for multi-sheet files (e.g. sales_target_plan, promotion_program)."""
    name = filename.lower()
    buf = io.BytesIO(raw_bytes)
    engine = 'pyxlsb' if name.endswith('.xlsb') else 'openpyxl'
    xls = pd.ExcelFile(buf, engine=engine)
    return xls.sheet_names
