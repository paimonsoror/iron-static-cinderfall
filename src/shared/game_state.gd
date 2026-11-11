class_name GameState
extends RefCounted
## Application-level state ids (ARCH 4). The sim owns PREPARING..DEFEAT; PAUSED exists only in Game.

enum Id { BOOT, MENU, BRIEFING, PREPARING, SPAWNING, CLEARING, INTERMISSION, VICTORY, DEFEAT, PAUSED }

const NAMES: PackedStringArray = ["BOOT", "MENU", "BRIEFING", "PREPARING", "SPAWNING", "CLEARING", "INTERMISSION", "VICTORY", "DEFEAT", "PAUSED"]


static func name_of(id: int) -> String:
	if id < 0 or id >= NAMES.size():
		return "UNKNOWN"
	return NAMES[id]


## PREPARING..DEFEAT.
static func is_run_phase(id: int) -> bool:
	return id >= Id.PREPARING and id <= Id.DEFEAT


## SPAWNING or CLEARING.
static func is_combat(id: int) -> bool:
	return id == Id.SPAWNING or id == Id.CLEARING


## VICTORY or DEFEAT.
static func is_terminal(id: int) -> bool:
	return id == Id.VICTORY or id == Id.DEFEAT
