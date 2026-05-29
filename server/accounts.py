"""File-backed unique-name registry (no passwords / email).

A player just picks a name. The name must be unique. On first claim the server
issues an invisible token that the client stores locally; presenting that token
later lets the same client reclaim its name (so nobody else can take it), which
also makes relaunch fast — the client auto-claims its saved name.

names.json layout: {"<name>": {"token": "<str>"}}
"""
import json
import os
import secrets
from pathlib import Path
from typing import Tuple

NAMES_PATH = Path(__file__).parent / "names.json"
_names: dict = {}


def load() -> None:
    global _names
    if NAMES_PATH.exists():
        with open(NAMES_PATH, "r", encoding="utf-8") as f:
            _names = json.load(f)
    else:
        _names = {}


def _save() -> None:
    tmp = NAMES_PATH.with_suffix(".json.tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(_names, f, ensure_ascii=False, indent=2)
    os.replace(tmp, NAMES_PATH)


def _valid(name: str) -> bool:
    return 1 <= len(name) <= 16 and "[" not in name and "]" not in name


def claim(name: str, token: str = "") -> Tuple[bool, str]:
    """Returns (ok, token_or_reason).

    - free name  -> register + new token
    - own name   -> reclaim (token matches)
    - taken name -> fail
    """
    name = (name or "").strip()
    if not _valid(name):
        return False, "이름은 1~16자여야 합니다."
    rec = _names.get(name)
    if rec is None:
        tok = secrets.token_urlsafe(24)
        _names[name] = {"token": tok}
        _save()
        return True, tok
    if token and secrets.compare_digest(rec.get("token", ""), token):
        return True, token
    return False, "이미 사용 중인 이름입니다."
