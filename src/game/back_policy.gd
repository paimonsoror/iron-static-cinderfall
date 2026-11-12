class_name BackPolicy
extends RefCounted
## What the Android back gesture does in each state (pure; GDD 10.2: "closes the open drawer or overlay; else pauses
## during combat; else goes one screen back; on the menu it asks to quit").
##
## `overlay_open` means an overlay on top of the current screen that the gesture may dismiss (the settings screen);
## it does NOT include the pause overlay itself, because in PAUSED the gesture means RESUME.
## `drawer_open` is the combat HUD's upgrade drawer.
## `choice_open` (variety milestone) means a choice overlay is up (salvage, draft, route, boss briefing): a choice can
## never be dismissed, so the gesture pauses.

enum Action { CLOSE_OVERLAY, CLOSE_DRAWER, PAUSE, RESUME, TO_MENU, CONFIRM_QUIT, NONE }


static func decide(state: int, drawer_open: bool, overlay_open: bool, choice_open: bool = false) -> int:
	if state == GameState.Id.BOOT:
		return Action.NONE
	if overlay_open:
		return Action.CLOSE_OVERLAY
	match state:
		GameState.Id.MENU:
			return Action.CONFIRM_QUIT
		GameState.Id.BRIEFING, GameState.Id.VICTORY, GameState.Id.DEFEAT:
			return Action.TO_MENU
		GameState.Id.PAUSED:
			return Action.RESUME
		GameState.Id.PREPARING, GameState.Id.SPAWNING, GameState.Id.CLEARING, GameState.Id.INTERMISSION:
			return Action.CLOSE_DRAWER if drawer_open and not choice_open else Action.PAUSE
	return Action.NONE
