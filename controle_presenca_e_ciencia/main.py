import json
import secrets
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Optional

from fastapi import Depends, FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

import auth
import graph
import sessions
from config import get_settings
from database import get_db, init_db
from models import ATA, Assignment

settings = get_settings()
SESSION_COOKIE = "ata_sid"


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(lifespan=lifespan, title="Sistema de ATAs")
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")


# ── Helpers ──────────────────────────────────────────────────────────────────

def _get_user(request: Request) -> Optional[dict]:
    sid = request.cookies.get(SESSION_COOKIE)
    if not sid:
        return None
    session = sessions.get_session(sid)
    return session.get("user") if session else None


def _require_user(request: Request) -> dict:
    user = _get_user(request)
    if not user:
        raise HTTPException(status_code=302, headers={"Location": "/login"})
    return user


def _set_cookie(response, sid: str):
    response.set_cookie(SESSION_COOKIE, sid, httponly=True, samesite="lax", max_age=86400 * 7)


# ── Auth routes ───────────────────────────────────────────────────────────────

@app.get("/login")
async def login(request: Request):
    state = secrets.token_urlsafe(16)
    sid = request.cookies.get(SESSION_COOKIE) or sessions.create_session()
    session = sessions.get_session(sid) or {}
    session["oauth_state"] = state
    sessions.set_session(sid, session)
    url = auth.get_auth_url(state)
    resp = RedirectResponse(url)
    _set_cookie(resp, sid)
    return resp


@app.get("/auth/callback", response_class=HTMLResponse)
async def auth_callback(request: Request, code: str = None, state: str = None, error: str = None):
    if error:
        return templates.TemplateResponse("login.html", {
            "request": request,
            "error": f"Erro de autenticação: {error}",
        })

    sid = request.cookies.get(SESSION_COOKIE)
    session = sessions.get_session(sid) if sid else None

    if not session or session.get("oauth_state") != state:
        return RedirectResponse("/login")

    result = auth.get_token_from_code(code)
    if "access_token" not in result:
        return templates.TemplateResponse("login.html", {
            "request": request,
            "error": "Falha na autenticação. Por favor tente novamente.",
        })

    me = await graph.get_current_user(result["access_token"])
    session["user"] = {
        "email": me.get("mail") or me.get("userPrincipalName", ""),
        "name": me.get("displayName", ""),
        "id": me.get("id", ""),
    }
    session.pop("oauth_state", None)
    sessions.set_session(sid, session)

    resp = RedirectResponse("/")
    _set_cookie(resp, sid)
    return resp


@app.get("/logout")
async def logout(request: Request):
    sid = request.cookies.get(SESSION_COOKIE)
    if sid:
        sessions.delete_session(sid)
    resp = RedirectResponse("/")
    resp.delete_cookie(SESSION_COOKIE)
    return resp


# ── Dashboard ─────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def home(request: Request, db: AsyncSession = Depends(get_db)):
    user = _get_user(request)
    if not user:
        return templates.TemplateResponse("login.html", {"request": request})

    email = user["email"]

    pending_q = await db.execute(
        select(Assignment)
        .where(Assignment.user_email == email, Assignment.signed_at.is_(None))
    )
    pending = pending_q.scalars().all()

    signed_q = await db.execute(
        select(Assignment)
        .where(Assignment.user_email == email, Assignment.signed_at.isnot(None))
        .order_by(Assignment.signed_at.desc())
    )
    signed = signed_q.scalars().all()

    created_q = await db.execute(
        select(ATA)
        .where(ATA.created_by_email == email)
        .order_by(ATA.created_at.desc())
    )
    created = created_q.scalars().all()

    return templates.TemplateResponse("index.html", {
        "request": request,
        "user": user,
        "pending": pending,
        "signed": signed,
        "created": created,
    })


# ── Create ATA ────────────────────────────────────────────────────────────────

@app.get("/atas/new", response_class=HTMLResponse)
async def ata_new_form(request: Request):
    user = _get_user(request)
    if not user:
        return RedirectResponse("/login")
    return templates.TemplateResponse("ata_create.html", {"request": request, "user": user})


@app.post("/atas/new")
async def ata_create(
    request: Request,
    title: str = Form(...),
    description: str = Form(""),
    sharepoint_url: str = Form(...),
    meeting_date: str = Form(""),
    recipients_json: str = Form(...),
    db: AsyncSession = Depends(get_db),
):
    user = _get_user(request)
    if not user:
        return RedirectResponse("/login")

    try:
        recipients = json.loads(recipients_json)
    except (json.JSONDecodeError, TypeError):
        recipients = []

    if not recipients:
        return templates.TemplateResponse("ata_create.html", {
            "request": request,
            "user": user,
            "error": "Adicione ao menos um destinatário.",
        })

    ata = ATA(
        title=title,
        description=description.strip() or None,
        sharepoint_url=sharepoint_url,
        meeting_date=meeting_date or None,
        created_by_email=user["email"],
        created_by_name=user["name"],
    )
    db.add(ata)
    await db.flush()

    for r in recipients:
        db.add(Assignment(
            ata_id=ata.id,
            user_email=r["email"],
            user_name=r.get("name", ""),
        ))

    await db.commit()
    await db.refresh(ata)

    # Send notifications (failures are logged, not fatal)
    base_url = str(request.base_url).rstrip("/")
    ata_url = f"{base_url}/atas/{ata.id}"
    for r in recipients:
        try:
            await graph.send_ata_notification(
                to_email=r["email"],
                to_name=r.get("name", r["email"]),
                ata_title=title,
                ata_url=ata_url,
                description=description.strip(),
            )
            res = await db.execute(
                select(Assignment).where(
                    and_(Assignment.ata_id == ata.id, Assignment.user_email == r["email"])
                )
            )
            a = res.scalar_one_or_none()
            if a:
                a.email_sent = True
                a.email_sent_at = datetime.utcnow()
        except Exception as exc:
            print(f"[email] Falha ao enviar para {r['email']}: {exc}")

    await db.commit()
    return RedirectResponse(f"/atas/{ata.id}/status", status_code=303)


# ── ATA detail / sign ─────────────────────────────────────────────────────────

@app.get("/atas/{ata_id}", response_class=HTMLResponse)
async def ata_detail(ata_id: int, request: Request, db: AsyncSession = Depends(get_db)):
    user = _get_user(request)
    if not user:
        return RedirectResponse("/login")

    res = await db.execute(select(ATA).where(ATA.id == ata_id))
    ata = res.scalar_one_or_none()
    if not ata:
        raise HTTPException(status_code=404, detail="ATA não encontrada")

    asgn_res = await db.execute(
        select(Assignment).where(
            and_(Assignment.ata_id == ata_id, Assignment.user_email == user["email"])
        )
    )
    assignment = asgn_res.scalar_one_or_none()

    return templates.TemplateResponse("ata_detail.html", {
        "request": request,
        "user": user,
        "ata": ata,
        "assignment": assignment,
        "is_creator": ata.created_by_email == user["email"],
    })


@app.post("/atas/{ata_id}/sign")
async def ata_sign(ata_id: int, request: Request, db: AsyncSession = Depends(get_db)):
    user = _get_user(request)
    if not user:
        return RedirectResponse("/login")

    res = await db.execute(
        select(Assignment).where(
            and_(
                Assignment.ata_id == ata_id,
                Assignment.user_email == user["email"],
                Assignment.signed_at.is_(None),
            )
        )
    )
    assignment = res.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=400, detail="Assinatura não permitida ou já realizada.")

    assignment.signed_at = datetime.utcnow()
    assignment.sign_ip = request.client.host if request.client else None
    await db.commit()

    return RedirectResponse(f"/atas/{ata_id}", status_code=303)


# ── Status (signatures) ───────────────────────────────────────────────────────

@app.get("/atas/{ata_id}/status", response_class=HTMLResponse)
async def ata_status(ata_id: int, request: Request, db: AsyncSession = Depends(get_db)):
    user = _get_user(request)
    if not user:
        return RedirectResponse("/login")

    res = await db.execute(select(ATA).where(ATA.id == ata_id))
    ata = res.scalar_one_or_none()
    if not ata:
        raise HTTPException(status_code=404)

    return templates.TemplateResponse("ata_status.html", {
        "request": request,
        "user": user,
        "ata": ata,
        "is_creator": ata.created_by_email == user["email"],
        "signed_count": sum(1 for a in ata.assignments if a.signed_at),
        "total_count": len(ata.assignments),
    })


# ── API: user search ──────────────────────────────────────────────────────────

@app.get("/api/users")
async def api_users(q: str = "", request: Request = None):
    user = _get_user(request)
    if not user:
        return JSONResponse({"error": "não autenticado"}, status_code=401)
    try:
        users = await graph.list_users(search=q)
        result = [
            {
                "email": u.get("mail") or u.get("userPrincipalName", ""),
                "name": u.get("displayName", ""),
            }
            for u in users
            if u.get("mail") or u.get("userPrincipalName")
        ]
        return JSONResponse(result)
    except Exception as exc:
        return JSONResponse({"error": str(exc)}, status_code=500)
