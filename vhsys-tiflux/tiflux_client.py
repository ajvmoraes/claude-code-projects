import logging
import httpx
from config import TIFLUX_TOKEN, TIFLUX_BASE_URL

logger = logging.getLogger(__name__)

HEADERS = {
    "Authorization": f"Bearer {TIFLUX_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def criar_cliente(payload: dict) -> dict:
    """
    Cria um cliente no TiFlux.

    Campos esperados no payload:
        name            (str, obrigatório) – nome fantasia
        social          (str, opcional)    – razão social
        social_revenue  (str, opcional)    – CNPJ ou CPF
        email           (str, opcional)
        phone           (str, opcional)
        status          (bool, opcional)   – True = ativo (padrão)

    Retorna o dict de resposta do TiFlux ou lança exceção em caso de erro.
    """
    url = f"{TIFLUX_BASE_URL}/clients"

    logger.info("Criando cliente no TiFlux: %s", payload.get("name"))

    with httpx.Client(timeout=30) as client:
        response = client.post(url, json=payload, headers=HEADERS)

    if response.status_code in (200, 201):
        data = response.json()
        logger.info("Cliente criado no TiFlux com sucesso. ID: %s", data.get("id"))
        return data

    logger.error(
        "Erro ao criar cliente no TiFlux. Status: %s | Body: %s",
        response.status_code,
        response.text,
    )
    response.raise_for_status()


def cliente_existe(document: str) -> bool:
    """
    Verifica se já existe um cliente com o CNPJ/CPF informado.
    Evita duplicatas caso o webhook seja disparado mais de uma vez.
    """
    if not document:
        return False

    url = f"{TIFLUX_BASE_URL}/clients"
    params = {"social_revenue": document}

    with httpx.Client(timeout=30) as client:
        response = client.get(url, params=params, headers=HEADERS)

    if response.status_code == 200:
        data = response.json()
        # A API retorna lista ou objeto paginado – ajuste conforme necessário
        items = data if isinstance(data, list) else data.get("data", [])
        return len(items) > 0

    return False
