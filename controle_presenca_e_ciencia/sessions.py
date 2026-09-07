import secrets
from typing import Any, Dict, Optional

_store: Dict[str, Dict[str, Any]] = {}


def create_session() -> str:
    sid = secrets.token_urlsafe(32)
    _store[sid] = {}
    return sid


def get_session(sid: str) -> Optional[Dict[str, Any]]:
    return _store.get(sid)


def set_session(sid: str, data: Dict[str, Any]) -> None:
    _store[sid] = data


def delete_session(sid: str) -> None:
    _store.pop(sid, None)
