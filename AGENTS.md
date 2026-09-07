# AGENTS.md

Quando eu falar sobre API de Tiflux, acesse: https://guia-de-uso.tiflux.com/integracoes/api-tiflux/api-v2
Quando eu falar sobre API do VHSYS, acesse: https://developers.vhsys.com.br/api/

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## GitHub Repository

This project is synced to **https://github.com/ajvmoraes/Codex-projects** (public, branch `main`).

### Auto-sync on session end

A `Stop` hook in `.Codex/settings.json` runs automatically when Codex finishes each session. It:
1. Checks `git status --porcelain` for any changes.
2. If changes exist: runs `git add -A`, commits with message `chore: auto-sync via Codex [timestamp]`, and `git push`.
3. If nothing changed: does nothing.

### Manual sync

```bash
cd "/Users/andre.moraes/Library/CloudStorage/OneDrive-AVSTecnologia®/Documentos/Codex"
git add -A
git commit -m "your message"
git push
```

### Initial setup (already done)

```bash
brew install gh
gh auth login
git init && git branch -M main
gh repo create ajvmoraes/Codex-projects --public
gh auth setup-git
git remote add origin https://github.com/ajvmoraes/Codex-projects.git
git push -u origin main
```

---

## Repository Layout

This directory contains two independent Python projects:

- `vhsys-tiflux/` — FastAPI webhook server that bridges VHSYS (ERP) and TiFlux (helpdesk), syncing new customers from VHSYS into TiFlux in real time.
- `stock-dashboard/` — Streamlit dashboard displaying B3 stock performance (Petrobras, Itaú, Vale) for 2025, using yfinance + Plotly.

---

## vhsys-tiflux

### Setup

```bash
cd vhsys-tiflux
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in tokens and credentials
```

### Run locally

```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```

### Register the webhook in VHSYS (one-time)

```bash
python setup_webhook.py
```

After running, the VHSYS user must log out and back in to activate webhook delivery.

### Production deployment

Deploy to `/opt/vhsys-tiflux/` on the VPS and manage via systemd:

```bash
sudo systemctl enable vhsys-tiflux
sudo systemctl start vhsys-tiflux
journalctl -u vhsys-tiflux -f   # follow logs
```

### Architecture

```
VHSYS ──POST──▶ /webhook/vhsys/clientes (Basic Auth)
                    │
                    ├─ app.py        – FastAPI endpoint, auth guard, event filtering
                    ├─ field_mapper.py – maps VHSYS payload fields → TiFlux schema
                    └─ tiflux_client.py – HTTP calls to TiFlux API (create, dedup by CNPJ/CPF)
```

Key behaviours:
- Only `create`/`cadastrar`/`insert` events are forwarded; all others return `{"status": "ignored"}`.
- Duplicate guard: before creating, `tiflux_client.cliente_existe()` queries TiFlux by `social_revenue` (CNPJ/CPF); skips if found.
- `fantasia_cliente` is used as the display name; falls back to `razao_cliente` when absent.
- All config is loaded from `.env` via `config.py`; missing required vars raise `KeyError` at startup.

### Required environment variables

| Variable | Purpose |
|---|---|
| `VHSYS_ACCESS_TOKEN` | VHSYS API token |
| `VHSYS_SECRET_ACCESS_TOKEN` | VHSYS secret token |
| `WEBHOOK_USERNAME` / `WEBHOOK_PASSWORD` | Basic Auth credentials (you define) |
| `TIFLUX_TOKEN` | TiFlux Bearer token |
| `PUBLIC_URL` | Public HTTPS URL of the server (used by `setup_webhook.py`) |
| `PORT` | Server port (default `8000`) |

---

## stock-dashboard

### Setup

```bash
cd stock-dashboard
pip install -r requirements.txt
```

### Run

```bash
streamlit run app.py
```

### Architecture

- `data.py` — defines `TICKERS` dict and `fetch_data()` (cached 1 h via `@st.cache_data`); downloads OHLCV from yfinance.
- `charts.py` — four Plotly chart functions (`plot_price_history`, `plot_cumulative_return`, `plot_candlestick`, `plot_volume`); reads `COLORS` from `data.py`.
- `app.py` — Streamlit UI: sidebar filters (ticker multiselect + date range), metric cards, and four charts split across tabs.

To add a new ticker, update `TICKERS` and `COLORS` in `data.py`; no other files need changing.
