"""Gravity Shift WebSocket server.

Run: python main.py
Default bind: 0.0.0.0:8765
"""
import asyncio
import json
import os
import secrets
import string
from http import HTTPStatus
from typing import Dict, Set, Optional, Any

import websockets

import protocol as P
import stages
import accounts
import profanity
from models import Room, Player, Block, Door, Button, Hazard
import game_logic as L

ALPHABET = string.ascii_letters + string.digits + "!@#%&"

rooms: Dict[str, Room] = {}
lobby_clients: Set[Any] = set()
ws_to_session: Dict[Any, "PlayerSession"] = {}
next_pid = 1
next_bid = 1


class PlayerSession:
    __slots__ = ("pid", "ws", "room_name", "username")

    def __init__(self, pid: int, ws: Any):
        self.pid = pid
        self.ws = ws
        self.room_name: Optional[str] = None
        self.username: Optional[str] = None


def generate_password() -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(P.PASSWORD_LENGTH))


async def send(ws, msg_type: str, **payload) -> None:
    try:
        await ws.send(json.dumps({"type": msg_type, **payload}))
    except websockets.ConnectionClosed:
        pass


async def broadcast_room(room: Room, msg_type: str, **payload) -> None:
    data = json.dumps({"type": msg_type, **payload})
    for p in list(room.players.values()):
        try:
            await p.ws.send(data)
        except websockets.ConnectionClosed:
            pass


def room_summaries() -> list:
    return [r.public_summary() for r in rooms.values()]


async def broadcast_lobby() -> None:
    msg = {"type": P.S2C_ROOMS_UPDATE, "rooms": room_summaries(),
           "count": len(rooms), "max": P.MAX_ROOMS}
    data = json.dumps(msg)
    for ws in list(lobby_clients):
        try:
            await ws.send(data)
        except websockets.ConnectionClosed:
            lobby_clients.discard(ws)


def instantiate_stage_into(room: Room, stage: dict) -> None:
    global next_bid
    # Only colors < required_players are in play (e.g. 2-player room ignores green).
    n = room.required_players
    room.spawns_by_color = {int(s["color"]): tuple(s["cell"])
                            for s in stage["spawns"] if int(s["color"]) < n}
    room.doors = [Door(color=int(d["color"]), cell=tuple(d["cell"]))
                  for d in stage["doors"] if int(d["color"]) < n]
    room.buttons = [Button(color=int(b["color"]), cell=tuple(b["cell"])) for b in stage.get("buttons", [])]
    room.hazards = [Hazard(kind=str(h["kind"]), cell=tuple(h["cell"])) for h in stage.get("hazards", [])]
    for b in stage["blocks"]:
        blk = Block(bid=next_bid, color=int(b["color"]), cell=tuple(b["cell"]))
        room.blocks[next_bid] = blk
        next_bid += 1


def reinstall_stage(room: Room, stage: dict) -> None:
    room.stage_id = int(stage["id"])
    room.stage_name = stage["name"]
    room.world = int(stage.get("world", 1))
    room.label = str(stage.get("label", str(stage["id"])))
    room.grid_w = int(stage["grid_w"])
    room.grid_h = int(stage["grid_h"])
    # required_players is the room's chosen count; keep it across stage advances.
    room.blocks.clear()
    room.doors.clear()
    room.buttons.clear()
    room.hazards.clear()
    room.spawns_by_color.clear()
    instantiate_stage_into(room, stage)
    for p in room.players.values():
        if p.color in room.spawns_by_color:
            p.cell = room.spawns_by_color[p.color]
    room.cleared = False
    room.started = True


def find_next_stage(room: Room) -> dict | None:
    for sid in stages.all_ids_sorted():
        if sid <= room.stage_id:
            continue
        s = stages.get(sid)
        if int(s["required_players"]) <= len(room.players):
            return s
    return None


def spawn_player_in_room(room: Room, session: PlayerSession) -> Player:
    used_colors = {p.color for p in room.players.values()}
    color = next(
        c for c in sorted(room.spawns_by_color.keys()) if c not in used_colors
    )
    spawn = room.spawns_by_color.get(color, (0, 0))
    player = Player(pid=session.pid, ws=session.ws, color=color, cell=spawn,
                    name=session.username or ("Player%d" % session.pid))
    room.players[session.pid] = player
    return player


async def handle_claim_name(session: PlayerSession, msg: dict) -> None:
    ok, result = accounts.claim(msg.get("name", ""), msg.get("token", ""))
    if ok:
        session.username = (msg.get("name") or "").strip()
        await send(session.ws, P.S2C_NAME_OK, name=session.username, token=result)
    else:
        await send(session.ws, P.S2C_NAME_FAIL, reason=result)


async def handle_chat(session: PlayerSession, msg: dict) -> None:
    if not session.room_name:
        return
    room = rooms.get(session.room_name)
    if room is None:
        return
    text = (msg.get("text") or "").strip()
    if not text:
        return
    text = profanity.censor(text[:200])
    await broadcast_room(room, P.S2C_CHAT, pid=session.pid,
                         name=session.username or "?", text=text)


async def handle_list_stages(session: PlayerSession, _msg: dict) -> None:
    await send(session.ws, P.S2C_STAGES_LIST, stages=stages.all_summaries())


async def handle_list_rooms(session: PlayerSession, _msg: dict) -> None:
    lobby_clients.add(session.ws)
    await send(session.ws, P.S2C_ROOMS_UPDATE,
               rooms=room_summaries(), count=len(rooms), max=P.MAX_ROOMS)


async def handle_autocomplete(session: PlayerSession, msg: dict) -> None:
    prefix = (msg.get("prefix") or "").lower()
    matches = [r.name for r in rooms.values() if r.name.lower().startswith(prefix)]
    await send(session.ws, P.S2C_AUTOCOMPLETE, matches=matches)


async def handle_create_room(session: PlayerSession, msg: dict) -> None:
    if not session.username:
        await send(session.ws, P.S2C_ROOM_CREATE_FAIL, reason="Log in first."); return
    name = (msg.get("name") or "").strip()
    stage_id = int(msg.get("stage_id", stages.all_ids_sorted()[0] if stages.all_ids_sorted() else 0))
    campaign = bool(msg.get("campaign", True))
    player_count = max(P.MIN_PLAYERS, min(P.MAX_PLAYERS, int(msg.get("player_count", P.MIN_PLAYERS))))
    stage = stages.get(stage_id)
    if stage is None:
        await send(session.ws, P.S2C_ROOM_CREATE_FAIL, reason="Unknown stage."); return
    if not name:
        await send(session.ws, P.S2C_ROOM_CREATE_FAIL, reason="Empty room name."); return
    if name in rooms:
        await send(session.ws, P.S2C_ROOM_CREATE_FAIL, reason="Name already taken."); return
    if len(rooms) >= P.MAX_ROOMS:
        await send(session.ws, P.S2C_ROOM_CREATE_FAIL,
                   reason=f"Server is full ({P.MAX_ROOMS} rooms max)."); return

    pwd = generate_password()
    room = Room(
        name=name, password=pwd, creator_pid=session.pid,
        stage_id=stage_id, stage_name=stage["name"],
        world=int(stage.get("world", 1)),
        label=str(stage.get("label", str(stage_id))),
        grid_w=int(stage["grid_w"]), grid_h=int(stage["grid_h"]),
        required_players=player_count,
        campaign=campaign,
    )
    instantiate_stage_into(room, stage)
    rooms[name] = room

    spawn_player_in_room(room, session)
    session.room_name = name
    lobby_clients.discard(session.ws)

    await send(session.ws, P.S2C_ROOM_CREATED, name=name, password=pwd,
               state=room.state_payload(), you=room.players[session.pid].to_dict())
    await broadcast_lobby()
    await maybe_start_stage(room)


async def handle_join_room(session: PlayerSession, msg: dict) -> None:
    if not session.username:
        await send(session.ws, P.S2C_ROOM_JOIN_FAIL, reason="Log in first."); return
    name = (msg.get("name") or "").strip()
    pwd  = msg.get("password") or ""
    room = rooms.get(name)
    if room is None:
        await send(session.ws, P.S2C_ROOM_JOIN_FAIL, reason="Room not found."); return
    # Password is optional: joining from the room list needs no password;
    # only reject when a non-empty password is sent and it doesn't match.
    if pwd and room.password != pwd:
        await send(session.ws, P.S2C_ROOM_JOIN_FAIL, reason="Wrong password."); return
    if room.is_full():
        await send(session.ws, P.S2C_ROOM_JOIN_FAIL, reason="Room is full."); return
    if room.started:
        await send(session.ws, P.S2C_ROOM_JOIN_FAIL, reason="Stage already started."); return

    player = spawn_player_in_room(room, session)
    session.room_name = name
    lobby_clients.discard(session.ws)

    await send(session.ws, P.S2C_ROOM_JOINED, name=name,
               state=room.state_payload(), you=player.to_dict())
    await broadcast_room(room, P.S2C_PLAYER_JOINED, player=player.to_dict())
    await broadcast_lobby()
    await maybe_start_stage(room)


async def maybe_start_stage(room: Room) -> None:
    if room.started: return
    if len(room.players) >= room.required_players:
        room.started = True
        await broadcast_room(room, P.S2C_STAGE_STARTED, **room.state_payload())


async def handle_leave_room(session: PlayerSession, _msg: dict) -> None:
    await cleanup_player(session, voluntary=True)


async def handle_move(session: PlayerSession, msg: dict) -> None:
    if not session.room_name: return
    room = rooms.get(session.room_name)
    if room is None: return
    player = room.players.get(session.pid)
    if player is None: return

    step = msg.get("step") or [0, 0]
    if not (isinstance(step, list) and len(step) == 2): return
    sx, sy = int(step[0]), int(step[1])
    if abs(sx) + abs(sy) != 1: return

    if L.try_move_player(room, player, (sx, sy)):
        await broadcast_room(room, P.S2C_STATE, **room.state_payload())
        if L.is_stage_cleared(room):
            room.cleared = True
            await broadcast_room(room, P.S2C_STAGE_CLEARED,
                                 stage_id=room.stage_id, stage_name=room.stage_name)
            asyncio.create_task(_advance_after_clear(room.name))


async def _advance_after_clear(room_name: str) -> None:
    await asyncio.sleep(2.5)
    room = rooms.get(room_name)
    if room is None or not room.cleared:
        return
    if room.campaign:
        nxt = find_next_stage(room)
        if nxt is not None:
            reinstall_stage(room, nxt)
            await broadcast_room(room, P.S2C_STAGE_STARTED, **room.state_payload())
            return
    await broadcast_room(room, P.S2C_ROOM_CLOSED, reason="All stages cleared!")
    rooms.pop(room.name, None)
    for p in list(room.players.values()):
        sess = ws_to_session.get(p.ws)
        if sess is not None:
            sess.room_name = None
    await broadcast_lobby()


async def handle_interact(session: PlayerSession, _msg: dict) -> None:
    # TODO: define interact once gravity-toggle vs block-grab is decided
    pass


HANDLERS = {
    P.C2S_CLAIM_NAME:    handle_claim_name,
    P.C2S_LIST_STAGES:   handle_list_stages,
    P.C2S_LIST_ROOMS:    handle_list_rooms,
    P.C2S_AUTOCOMPLETE:  handle_autocomplete,
    P.C2S_CREATE_ROOM:   handle_create_room,
    P.C2S_JOIN_ROOM:     handle_join_room,
    P.C2S_LEAVE_ROOM:    handle_leave_room,
    P.C2S_MOVE:          handle_move,
    P.C2S_INTERACT:      handle_interact,
    P.C2S_CHAT:          handle_chat,
}


async def cleanup_player(session: PlayerSession, voluntary: bool) -> None:
    lobby_clients.discard(session.ws)
    if not session.room_name:
        return
    room = rooms.get(session.room_name)
    session.room_name = None
    if room is None:
        return

    is_creator = (room.creator_pid == session.pid)
    room.players.pop(session.pid, None)

    if is_creator:
        await broadcast_room(room, P.S2C_ROOM_CLOSED, reason="Host left.")
        rooms.pop(room.name, None)
    else:
        await broadcast_room(room, P.S2C_PLAYER_LEFT, pid=session.pid)
        if not room.players:
            rooms.pop(room.name, None)

    await broadcast_lobby()


async def handler(ws):
    global next_pid
    session = PlayerSession(pid=next_pid, ws=ws)
    next_pid += 1
    ws_to_session[ws] = session
    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await send(ws, P.S2C_ERROR, reason="Bad JSON."); continue
            t = msg.get("type")
            fn = HANDLERS.get(t)
            if fn is None:
                await send(ws, P.S2C_ERROR, reason=f"Unknown type: {t}")
                continue
            await fn(session, msg)
    except websockets.ConnectionClosed:
        pass
    finally:
        await cleanup_player(session, voluntary=False)
        ws_to_session.pop(ws, None)


def health_check(connection, request):
    """Answer plain HTTP probes (e.g. Render health checks) with 200; let
    real WebSocket upgrade requests through to the game handler."""
    if request.headers.get("Upgrade", "").lower() != "websocket":
        return connection.respond(HTTPStatus.OK, "Gravity Shift server OK\n")
    return None


async def main() -> None:
    stages.load_all()
    accounts.load()
    profanity.load()
    print(f"Loaded {len(stages.all_summaries())} stages.")
    host = os.getenv("GS_HOST", "0.0.0.0")
    # Render (and most PaaS) inject the port to bind via $PORT.
    port = int(os.getenv("PORT", os.getenv("GS_PORT", "8765")))
    print(f"Gravity Shift server listening on :{port}")
    async with websockets.serve(handler, host, port, max_size=2**16,
                                process_request=health_check):
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nshutting down.")
