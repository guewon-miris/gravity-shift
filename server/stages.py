"""Loads stage definitions from server/stages/*.json on startup."""
import json
from pathlib import Path
from typing import Dict, List

STAGES_DIR = Path(__file__).parent / "stages"
_stages: Dict[int, dict] = {}


def load_all() -> None:
    _stages.clear()
    for path in sorted(STAGES_DIR.glob("*.json")):
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        _stages[int(data["id"])] = data


def get(stage_id: int) -> dict | None:
    return _stages.get(stage_id)


def all_ids_sorted() -> List[int]:
    return sorted(_stages.keys())


def all_summaries() -> List[dict]:
    return [
        {
            "id": s["id"],
            "name": s["name"],
            "world": s.get("world", 1),
            "label": s.get("label", str(s["id"])),
            "grid_w": s["grid_w"],
            "grid_h": s["grid_h"],
            "required_players": s["required_players"],
        }
        for s in sorted(_stages.values(), key=lambda x: x["id"])
    ]
