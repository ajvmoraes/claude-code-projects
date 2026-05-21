import os
from dotenv import load_dotenv

load_dotenv()

# VHSYS
VHSYS_ACCESS_TOKEN = os.environ["VHSYS_ACCESS_TOKEN"]
VHSYS_SECRET_ACCESS_TOKEN = os.environ["VHSYS_SECRET_ACCESS_TOKEN"]
VHSYS_BASE_URL = "https://api.vhsys.com/v2"

# Credenciais do webhook (você define ao registrar o webhook no VHSYS)
WEBHOOK_USERNAME = os.environ["WEBHOOK_USERNAME"]
WEBHOOK_PASSWORD = os.environ["WEBHOOK_PASSWORD"]

# TiFlux
TIFLUX_TOKEN = os.environ["TIFLUX_TOKEN"]
TIFLUX_BASE_URL = "https://api.tiflux.com/api/v2"

# Servidor
PORT = int(os.getenv("PORT", "8000"))
PUBLIC_URL = os.getenv("PUBLIC_URL", "http://localhost:8000")
