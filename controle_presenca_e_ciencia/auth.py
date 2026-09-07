import msal
from config import get_settings

settings = get_settings()

AUTHORITY = f"https://login.microsoftonline.com/{settings.TENANT_ID}"

# Delegated scopes — used for user login
USER_SCOPES = ["User.Read", "openid", "profile", "email", "offline_access"]


def _get_msal_app() -> msal.ConfidentialClientApplication:
    return msal.ConfidentialClientApplication(
        client_id=settings.CLIENT_ID,
        client_credential=settings.CLIENT_SECRET,
        authority=AUTHORITY,
    )


def get_auth_url(state: str) -> str:
    return _get_msal_app().get_authorization_request_url(
        scopes=USER_SCOPES,
        state=state,
        redirect_uri=settings.REDIRECT_URI,
    )


def get_token_from_code(code: str) -> dict:
    return _get_msal_app().acquire_token_by_authorization_code(
        code=code,
        scopes=USER_SCOPES,
        redirect_uri=settings.REDIRECT_URI,
    )


def get_app_token() -> str:
    """Client-credentials token for server-side Graph calls (user listing, send email)."""
    result = _get_msal_app().acquire_token_for_client(
        scopes=["https://graph.microsoft.com/.default"]
    )
    if "access_token" not in result:
        raise RuntimeError(
            f"Falha ao obter token de aplicação: {result.get('error_description', result)}"
        )
    return result["access_token"]
