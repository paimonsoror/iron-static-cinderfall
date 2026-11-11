class_name GameStateMachine
extends RefCounted
## Application state machine (ARCH 4.1). Illegal transitions return false and change nothing.

var current: int = GameState.Id.BOOT
var previous: int = GameState.Id.BOOT
var paused_from: int = -1  ## state to return to on resume


## Static legality. From PAUSED every resume target is listed; transition() additionally
## insists that a resume goes back to `paused_from`.
static func can_transition(from: int, to: int) -> bool:
	match from:
		GameState.Id.BOOT:
			return to == GameState.Id.MENU
		GameState.Id.MENU:
			return to == GameState.Id.BRIEFING
		GameState.Id.BRIEFING:
			return to == GameState.Id.MENU or to == GameState.Id.PREPARING
		GameState.Id.PREPARING:
			return to == GameState.Id.SPAWNING or to == GameState.Id.PAUSED
		GameState.Id.SPAWNING:
			return to == GameState.Id.CLEARING or to == GameState.Id.DEFEAT or to == GameState.Id.PAUSED
		GameState.Id.CLEARING:
			return (
				to == GameState.Id.INTERMISSION
				or to == GameState.Id.VICTORY
				or to == GameState.Id.DEFEAT
				or to == GameState.Id.PAUSED
			)
		GameState.Id.INTERMISSION:
			return to == GameState.Id.SPAWNING or to == GameState.Id.PAUSED
		GameState.Id.PAUSED:
			return (
				to == GameState.Id.PREPARING
				or to == GameState.Id.MENU
				or to == GameState.Id.SPAWNING
				or to == GameState.Id.CLEARING
				or to == GameState.Id.INTERMISSION
			)
		GameState.Id.VICTORY, GameState.Id.DEFEAT:
			return to == GameState.Id.PREPARING or to == GameState.Id.MENU
	return false


func transition(to: int) -> bool:
	if not can_transition(current, to):
		return false
	if current == GameState.Id.PAUSED:
		var resume_only: bool = (
			to == GameState.Id.SPAWNING or to == GameState.Id.CLEARING or to == GameState.Id.INTERMISSION
		)
		if resume_only and to != paused_from:
			return false
	previous = current
	current = to
	if to == GameState.Id.PAUSED:
		paused_from = previous
	else:
		paused_from = -1
	return true
