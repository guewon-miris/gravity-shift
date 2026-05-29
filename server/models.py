from dataclasses import dataclass, field
from typing import Dict, Tuple, Any, List


@dataclass
class Player:
    pid: int
    ws: Any
    color: int = 0
    cell: Tuple[int, int] = (0, 0)
    gravity: int = 0  # 0=S, 1=E, 2=N, 3=W
    name: str = ""

    def to_dict(self) -> dict:
        return {
            "pid": self.pid,
            "color": self.color,
            "cell": list(self.cell),
            "gravity": self.gravity,
            "name": self.name,
        }


@dataclass
class Block:
    bid: int
    color: int
    cell: Tuple[int, int]

    def to_dict(self) -> dict:
        return {"bid": self.bid, "color": self.color, "cell": list(self.cell)}


@dataclass
class Door:
    color: int
    cell: Tuple[int, int]

    def to_dict(self) -> dict:
        return {"color": self.color, "cell": list(self.cell)}


@dataclass
class Button:
    color: int
    cell: Tuple[int, int]
    pressed: bool = False

    def to_dict(self) -> dict:
        return {"color": self.color, "cell": list(self.cell), "pressed": self.pressed}


@dataclass
class Hazard:
    kind: str  # lava | spike | hole | laser
    cell: Tuple[int, int]

    def to_dict(self) -> dict:
        return {"kind": self.kind, "cell": list(self.cell)}


@dataclass
class Room:
    name: str
    password: str
    creator_pid: int
    stage_id: int
    stage_name: str
    grid_w: int
    grid_h: int
    required_players: int
    world: int = 1
    label: str = ""
    spawns_by_color: Dict[int, Tuple[int, int]] = field(default_factory=dict)
    doors: List[Door] = field(default_factory=list)
    buttons: List[Button] = field(default_factory=list)
    hazards: List[Hazard] = field(default_factory=list)
    players: Dict[int, Player] = field(default_factory=dict)
    blocks: Dict[int, Block] = field(default_factory=dict)
    started: bool = False
    cleared: bool = False
    campaign: bool = True

    def is_full(self) -> bool:
        return len(self.players) >= self.required_players

    def public_summary(self) -> dict:
        return {
            "name": self.name,
            "stage_id": self.stage_id,
            "stage_name": self.stage_name,
            "world": self.world,
            "label": self.label,
            "players": len(self.players),
            "required_players": self.required_players,
            "started": self.started,
        }

    def state_payload(self) -> dict:
        return {
            "stage_id": self.stage_id,
            "stage_name": self.stage_name,
            "world": self.world,
            "label": self.label,
            "grid_w": self.grid_w,
            "grid_h": self.grid_h,
            "required_players": self.required_players,
            "players": [p.to_dict() for p in self.players.values()],
            "blocks":  [b.to_dict() for b in self.blocks.values()],
            "doors":   [d.to_dict() for d in self.doors],
            "buttons": [b.to_dict() for b in self.buttons],
            "hazards": [h.to_dict() for h in self.hazards],
            "started": self.started,
            "cleared": self.cleared,
        }
