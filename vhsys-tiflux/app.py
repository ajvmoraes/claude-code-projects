"""
Servidor webhook: recebe eventos do VHSYS e cria clientes no TiFlux.

Execução local:
    uvicorn app:app --host 0.0.0.0 --port 8000

Em produção, use o serviço systemd fornecido (vhsys-tiflux.service).
"""

import logging
import secrets
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse

import tiflux_client
from config import PORT, WEBHOOK_PASSWORD, WEBHOOK_USERNAME
from field_mapper import vhsys_para_tiflux

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s – %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(title="VHSYS → TiFlux", docs_url=None, redoc_url=None)


# ─── Autenticação Basic Auth ──────────────────────────────────────────────────

def _verificar_auth(request: Request) -> None:
    """Valida as credenciais Basic Auth enviadas pelo VHSYS."""
    credentials = request.headers.get("Authorization", "")
    if not credentials.startswith("Basic "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticação necessária",
            headers={"WWW-Authenticate": "Basic"},
        )

    import base64
    try:
        decoded = base64.b64decode(credentials[6:]).decode("utf-8")
        username, _, password = decoded.partition(":")
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciais inválidas")

    usuario_ok = secrets.compare_digest(username, WEBHOOK_USERNAME)
    senha_ok = secrets.compare_digest(password, WEBHOOK_PASSWORD)

    if not (usuario_ok and senha_ok):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciais inválidas")


# ─── Endpoint do webhook ──────────────────────────────────────────────────────

@app.post("/webhook/vhsys/clientes")
async def receber_cliente(request: Request) -> JSONResponse:
    """
    Recebe o payload do webhook VHSYS para a entidade 'clientes'
    e cria o cliente correspondente no TiFlux.
    """
    _verificar_auth(request)

    try:
        payload: Any = await request.json()
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="JSON inválido")

    logger.info("Payload recebido do VHSYS: %s", payload)

    # O VHSYS pode envolver o objeto em uma chave; tenta extrair
    dados_cliente: dict = {}
    if isinstance(payload, dict):
        # Formatos possíveis: {"data": {...}} ou diretamente os campos
        dados_cliente = payload.get("data") or payload.get("cliente") or payload
    else:
        logger.warning("Payload inesperado (não é dict): %s", type(payload))
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Formato de payload não reconhecido")

    # Ignora eventos que não sejam de criação (se o VHSYS informar o tipo)
    evento = payload.get("event") or payload.get("acao") or ""
    if evento and evento.lower() not in ("", "create", "cadastrar", "insert"):
        logger.info("Evento '%s' ignorado (apenas criações são sincronizadas)", evento)
        return JSONResponse({"status": "ignored", "reason": f"evento '{evento}' não sincronizado"})

    if not dados_cliente.get("razao_cliente") and not dados_cliente.get("fantasia_cliente"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Payload não contém nome do cliente (razao_cliente / fantasia_cliente)",
        )

    # Verificar duplicata pelo CNPJ/CPF
    documento = dados_cliente.get("cnpj_cliente", "")
    if documento and tiflux_client.cliente_existe(documento):
        logger.info("Cliente com documento %s já existe no TiFlux. Ignorando.", documento)
        return JSONResponse({"status": "skipped", "reason": "cliente já existe no TiFlux"})

    # Mapear campos e criar no TiFlux
    payload_tiflux = vhsys_para_tiflux(dados_cliente)
    logger.info("Enviando para TiFlux: %s", payload_tiflux)

    try:
        resultado = tiflux_client.criar_cliente(payload_tiflux)
    except Exception as exc:
        logger.exception("Falha ao criar cliente no TiFlux")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Erro ao criar cliente no TiFlux: {exc}",
        )

    return JSONResponse({"status": "ok", "tiflux_id": resultado.get("id")}, status_code=201)


# ─── Health check ─────────────────────────────────────────────────────────────

@app.get("/health")
def health() -> JSONResponse:
    return JSONResponse({"status": "ok"})


# ─── Entrypoint ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=PORT, reload=False)
