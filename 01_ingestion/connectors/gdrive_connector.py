"""
Google Drive connector (Subtask 1.1.2).

Requires a Google Service Account JSON key — Coach provides this.
Share the target Drive folder(s) with the service account's email address,
otherwise list_files_in_folder() will return an empty list.

pip install google-auth google-api-python-client
"""
import os
from dotenv import load_dotenv

load_dotenv()

SCOPES = ['https://www.googleapis.com/auth/drive.readonly']
SERVICE_ACCOUNT_JSON = os.getenv('GOOGLE_SERVICE_ACCOUNT_JSON')


def get_service():
    """Build and return an authenticated Drive API service object."""
    from google.oauth2 import service_account
    from googleapiclient.discovery import build

    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_JSON, scopes=SCOPES
    )
    return build('drive', 'v3', credentials=creds)


def list_files_in_folder(folder_id: str) -> list[dict]:
    """Return [{'id':..., 'name':..., 'mimeType':...}, ...] for a Drive folder."""
    service = get_service()
    query = f"'{folder_id}' in parents and trashed = false"
    results = []
    page_token = None
    while True:
        resp = service.files().list(
            q=query,
            fields='nextPageToken, files(id, name, mimeType, modifiedTime)',
            pageToken=page_token,
        ).execute()
        results.extend(resp.get('files', []))
        page_token = resp.get('nextPageToken')
        if not page_token:
            break
    return results


def download_file_as_bytes(file_id: str) -> bytes:
    """Download a file's raw content by its Drive file ID."""
    import io
    from googleapiclient.http import MediaIoBaseDownload

    service = get_service()
    request = service.files().get_media(fileId=file_id)
    buf = io.BytesIO()
    downloader = MediaIoBaseDownload(buf, request)
    done = False
    while not done:
        _, done = downloader.next_chunk()
    return buf.getvalue()


if __name__ == '__main__':
    # Quick manual test — replace with a real folder ID before running
    test_folder_id = 'your_gdrive_folder_id_here'
    files = list_files_in_folder(test_folder_id)
    print(f'Found {len(files)} file(s)')
    for f in files:
        print(' -', f['name'])
