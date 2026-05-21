import re


def _limpar_documento(doc: str | None) -> str:
    """Remove pontuação do CNPJ/CPF."""
    if not doc:
        return ""
    return re.sub(r"[.\-/]", "", doc).strip()


def vhsys_para_tiflux(dados: dict) -> dict:
    """
    Converte o payload de cliente do VHSYS para o formato esperado pela API do TiFlux.

    Campos VHSYS utilizados:
        razao_cliente   – razão social
        fantasia_cliente – nome fantasia
        cnpj_cliente    – CNPJ ou CPF
        email_cliente   – e-mail
        fone_cliente    – telefone fixo
        celular_cliente – celular
        situacao_cliente – 'A' ativo / 'I' inativo

    Se o campo `fantasia_cliente` estiver vazio, usa `razao_cliente` como nome
    (comportamento comum para pessoas físicas).
    """
    razao = (dados.get("razao_cliente") or "").strip()
    fantasia = (dados.get("fantasia_cliente") or "").strip()
    nome = fantasia or razao

    documento = _limpar_documento(dados.get("cnpj_cliente"))
    email = (dados.get("email_cliente") or "").strip() or None
    telefone = (dados.get("fone_cliente") or dados.get("celular_cliente") or "").strip() or None
    situacao = (dados.get("situacao_cliente") or "A").upper()

    payload: dict = {
        "name": nome,
        "social": razao or None,
        "social_revenue": documento or None,
        "status": situacao == "A",
    }

    if email:
        payload["email"] = email
    if telefone:
        payload["phone"] = telefone

    # Remove campos None para não enviar nulos desnecessários
    return {k: v for k, v in payload.items() if v is not None}
