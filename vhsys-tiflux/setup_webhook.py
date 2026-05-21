"""
Registra (ou atualiza) o webhook de clientes no VHSYS.

Execute uma única vez após subir o servidor na VPS:
    python setup_webhook.py

O script verifica se já existe um webhook cadastrado para a URL configurada
e, se sim, atualiza em vez de duplicar.
"""

import sys
import httpx
from config import (
    PUBLIC_URL,
    VHSYS_ACCESS_TOKEN,
    VHSYS_BASE_URL,
    VHSYS_SECRET_ACCESS_TOKEN,
    WEBHOOK_PASSWORD,
    WEBHOOK_USERNAME,
)

HEADERS = {
    "access-token": VHSYS_ACCESS_TOKEN,
    "secret-access-token": VHSYS_SECRET_ACCESS_TOKEN,
    "Content-Type": "application/json",
    "Cache-Control": "no-cache",
}

WEBHOOK_URL = f"{PUBLIC_URL}/webhook/vhsys/clientes"

PAYLOAD = {
    "url": WEBHOOK_URL,
    "usuario": WEBHOOK_USERNAME,
    "senha": WEBHOOK_PASSWORD,
    "entidade": "clientes",
}


def listar_webhooks() -> list[dict]:
    r = httpx.get(f"{VHSYS_BASE_URL}/webhooks", headers=HEADERS, timeout=30)
    r.raise_for_status()
    data = r.json()
    return data if isinstance(data, list) else data.get("data", [])


def cadastrar_webhook() -> dict:
    r = httpx.post(f"{VHSYS_BASE_URL}/webhooks", json=PAYLOAD, headers=HEADERS, timeout=30)
    r.raise_for_status()
    return r.json()


def atualizar_webhook(webhook_id: int | str) -> dict:
    r = httpx.put(
        f"{VHSYS_BASE_URL}/webhooks/{webhook_id}",
        json=PAYLOAD,
        headers=HEADERS,
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def main() -> None:
    print(f"URL do webhook que será registrada: {WEBHOOK_URL}\n")

    print("Buscando webhooks existentes no VHSYS...")
    try:
        webhooks = listar_webhooks()
    except httpx.HTTPStatusError as e:
        print(f"Erro ao listar webhooks: {e.response.status_code} – {e.response.text}")
        sys.exit(1)

    # Procura por webhook com a mesma URL ou mesma entidade 'clientes'
    existente = next(
        (w for w in webhooks if w.get("url") == WEBHOOK_URL or w.get("entidade") == "clientes"),
        None,
    )

    if existente:
        wid = existente.get("id") or existente.get("codigo_webhook")
        print(f"Webhook existente encontrado (ID {wid}). Atualizando...")
        resultado = atualizar_webhook(wid)
        print("Webhook atualizado com sucesso!")
    else:
        print("Nenhum webhook encontrado. Cadastrando novo...")
        resultado = cadastrar_webhook()
        print("Webhook cadastrado com sucesso!")

    print(f"\nResposta: {resultado}")
    print(
        "\n⚠️  Importante: após cadastrar o webhook, o usuário do VHSYS precisa "
        "fazer logout e login novamente para ativar as transmissões."
    )


if __name__ == "__main__":
    main()
