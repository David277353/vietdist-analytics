"""
DB utils (Subtask 1.3.1) — engine, metadata helper, bronze loader.
"""
import os
import uuid
from datetime import datetime
from urllib.parse import quote_plus

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

_engine = None


def get_engine():
    """Singleton SQLAlchemy engine built from .env DB_* variables."""
    global _engine
    if _engine is None:
        user = os.getenv('DB_USER')
        password = os.getenv('DB_PASSWORD')
        host = os.getenv('DB_HOST')
        port = os.getenv('DB_PORT')
        dbname = os.getenv('DB_NAME')

        missing = [k for k, v in {
            'DB_USER': user, 'DB_PASSWORD': password, 'DB_HOST': host,
            'DB_PORT': port, 'DB_NAME': dbname,
        }.items() if not v]
        if missing:
            raise RuntimeError(
                f"Missing .env value(s): {', '.join(missing)}. "
                f"Check that vietdist_analytics/.env exists and is filled in."
            )

        # URL-encode user/password in case they contain special characters (@, #, %, :, etc.)
        url = (
            f"postgresql+psycopg2://{quote_plus(user)}:{quote_plus(password)}"
            f"@{host}:{port}/{dbname}"
        )
        _engine = create_engine(url)
    return _engine


def add_metadata(df: pd.DataFrame, source_file: str, source_platform: str, batch_id: str) -> pd.DataFrame:
    """Add the 4 required Bronze metadata columns. Cast everything else to TEXT."""
    df = df.copy()
    df = df.astype(str)
    df['_source_file'] = source_file
    df['_source_platform'] = source_platform
    df['_ingested_at'] = datetime.now()
    df['_batch_id'] = batch_id
    return df


def load_to_bronze(df: pd.DataFrame, table_name: str, if_exists: str = 'append', schema: str = 'raw') -> int:
    """Write a DataFrame to the raw schema. Returns row count loaded."""
    engine = get_engine()
    df.to_sql(table_name, engine, schema=schema, if_exists=if_exists, index=False)
    return len(df)


def new_batch_id() -> str:
    return str(uuid.uuid4())
