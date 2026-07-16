"""
OneDrive connector (Subtask 1.2.2) via Microsoft Graph API + MSAL.

Requires an Azure AD app registration — Coach provides client_id / tenant_id /
client_secret. Grant the app 'Files.Read.All' application permission (admin consent).

pip install msal requests
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()

CLIENT_ID = os.getenv('AZURE_CLIENT_ID')
CLIENT_SECRET = os.getenv('AZURE_CLIENT_SECRET')
TENANT_ID = os.getenv('AZURE_TENANT_ID')
GRAPH_ROOT = 'https://graph.microsoft.com/v1.0'


def get_access_token() -> str:
    """Acquire an app-only access token via client credentials flow."""
    import msal

    authority = f'https://login.microsoftonline.com/{TENANT_ID}'
    app = msal.ConfidentialClientApplication(
        CLIENT_ID, authority=authority, client_credential=CLIENT_SECRET
    )
    result = app.acquire_token_for_client(scopes=['https://graph.microsoft.com/.default'])
    if 'access_token' not in result:
        raise RuntimeError(f"Token error: {result.get('error_description')}")
    return result['access_token']


def _headers() -> dict:
    return {'Authorization': f'Bearer {get_access_token()}'}


def list_files_in_folder(drive_id: str, folder_path: str) -> list[dict]:
    """
    List files in a OneDrive folder.
    folder_path example: 'Sales/TargetPlans' (relative to drive root)
    """
    url = f'{GRAPH_ROOT}/drives/{drive_id}/root:/{folder_path}:/children'
    resp = requests.get(url, headers=_headers())
    resp.raise_for_status()
    return resp.json().get('value', [])


def download_file_as_bytes(drive_id: str, item_id: str) -> bytes:
    """Download a file's raw content by its Graph item ID."""
    url = f'{GRAPH_ROOT}/drives/{drive_id}/items/{item_id}/content'
    resp = requests.get(url, headers=_headers())
    resp.raise_for_status()
    return resp.content


if __name__ == '__main__':
    token = get_access_token()
    print('Token acquired, length:', len(token))
