from typing import Tuple
from models import Room, Player


def in_bounds(room: Room, cell: Tuple[int, int]) -> bool:
    x, y = cell
    return 0 <= x < room.grid_w and 0 <= y < room.grid_h


def cell_occupied_by_player(room: Room, cell: Tuple[int, int], except_pid: int = -1) -> bool:
    return any(p.cell == cell and p.pid != except_pid for p in room.players.values())


def block_at(room: Room, cell: Tuple[int, int]):
    for b in room.blocks.values():
        if b.cell == cell:
            return b
    return None


def hazard_at(room: Room, cell: Tuple[int, int]):
    for h in room.hazards:
        if h.cell == cell:
            return h
    return None


def door_at(room: Room, cell: Tuple[int, int]):
    for d in room.doors:
        if d.cell == cell:
            return d
    return None


def refresh_buttons(room: Room) -> None:
    """Latching: a button stays pressed once a player or block sits on it."""
    for b in room.buttons:
        if b.pressed:
            continue
        if cell_occupied_by_player(room, b.cell) or block_at(room, b.cell) is not None:
            b.pressed = True


def try_move_player(room: Room, player: Player, step: Tuple[int, int]) -> bool:
    if room.cleared or not room.started:
        return False
    nx, ny = player.cell[0] + step[0], player.cell[1] + step[1]
    target = (nx, ny)
    if not in_bounds(room, target):
        return False
    if cell_occupied_by_player(room, target, except_pid=player.pid):
        return False

    blocking = block_at(room, target)
    if blocking is not None:
        if blocking.color != player.color:
            return False
        push_to = (target[0] + step[0], target[1] + step[1])
        if not in_bounds(room, push_to):
            return False
        if block_at(room, push_to) is not None or cell_occupied_by_player(room, push_to):
            return False
        blocking.cell = push_to

    player.cell = target

    # Hazard cells send the player back to their spawn.
    if hazard_at(room, target) is not None:
        spawn = room.spawns_by_color.get(player.color)
        if spawn is not None:
            player.cell = spawn

    refresh_buttons(room)
    return True


def is_stage_cleared(room: Room) -> bool:
    if not room.started or room.cleared:
        return False
    if any(not b.pressed for b in room.buttons):
        return False
    for p in room.players.values():
        d = door_at(room, p.cell)
        if d is None or d.color != p.color:
            return False
    return True
