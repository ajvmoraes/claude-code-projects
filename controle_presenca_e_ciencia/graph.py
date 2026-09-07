from typing import Dict, List

import httpx

import auth
from config import get_settings

settings = get_settings()
GRAPH = "https://graph.microsoft.com/v1.0"


async def get_current_user(access_token: str) -> Dict:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{GRAPH}/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        resp.raise_for_status()
        return resp.json()


async def list_users(search: str = "") -> List[Dict]:
    token = auth.get_app_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "ConsistencyLevel": "eventual",  # required for $search
    }
    params: Dict = {
        "$select": "displayName,mail,userPrincipalName",
        "$top": "25",
        "$orderby": "displayName",
        "$filter": "accountEnabled eq true",
    }
    if search:
        # $search and $filter cannot be used together; drop filter when searching
        del params["$filter"]
        params["$search"] = f'"displayName:{search}" OR "mail:{search}"'

    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{GRAPH}/users", headers=headers, params=params)
        resp.raise_for_status()
        return resp.json().get("value", [])


async def send_email(to_email: str, to_name: str, subject: str, html_body: str) -> None:
    """Send email via Graph API using the FROM_EMAIL account (requires Mail.Send app permission)."""
    token = auth.get_app_token()
    payload = {
        "message": {
            "subject": subject,
            "body": {"contentType": "HTML", "content": html_body},
            "toRecipients": [{"emailAddress": {"address": to_email, "name": to_name}}],
        },
        "saveToSentItems": False,
    }
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{GRAPH}/users/{settings.FROM_EMAIL}/sendMail",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=15,
        )
        resp.raise_for_status()


def _build_email_html(to_name: str, ata_title: str, ata_url: str, description: str) -> str:
    desc_block = f'<p style="color:#605E5C;">{description}</p>' if description else ""
    return f"""
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#F3F2F1;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.1);">
        <tr>
          <td style="background:#0078D4;padding:28px 32px;">
            <h1 style="margin:0;color:#fff;font-size:20px;font-weight:600;">📋 ATA para Assinatura</h1>
          </td>
        </tr>
        <tr>
          <td style="padding:32px;">
            <p style="margin:0 0 16px;color:#323130;">Olá, <strong>{to_name}</strong>!</p>
            <p style="margin:0 0 16px;color:#323130;">Você recebeu uma ATA de reunião que requer sua leitura e assinatura:</p>
            <div style="background:#EFF6FC;border-left:4px solid #0078D4;padding:16px 20px;border-radius:4px;margin:20px 0;">
              <p style="margin:0;font-size:16px;font-weight:600;color:#323130;">{ata_title}</p>
              {desc_block}
            </div>
            <p style="color:#323130;">Acesse o sistema, leia o documento e confirme que está ciente do conteúdo:</p>
            <a href="{ata_url}" style="display:inline-block;background:#0078D4;color:#fff;padding:13px 28px;border-radius:4px;text-decoration:none;font-weight:600;font-size:15px;margin-top:8px;">
              Acessar e Assinar ATA →
            </a>
          </td>
        </tr>
        <tr>
          <td style="padding:20px 32px;border-top:1px solid #EDEBE9;">
            <p style="margin:0;color:#8A8886;font-size:12px;">
              Este é um e-mail automático do {settings.FROM_NAME}. Não responda a este e-mail.
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
"""


async def send_ata_notification(
    to_email: str, to_name: str, ata_title: str, ata_url: str, description: str = ""
) -> None:
    html = _build_email_html(to_name, ata_title, ata_url, description)
    await send_email(
        to_email=to_email,
        to_name=to_name,
        subject=f"[ATA] {ata_title} — Assinatura Requerida",
        html_body=html,
    )
