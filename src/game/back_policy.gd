class_name BackPolicy
extends RefCounted
## What the Android back gesture does in each state (pure; GDD 10.2: "closes the open overlay; else pauses
## during combat; else goes one screen back; on the menu it asks to quit").
##
## `overlay_open` means an overlay on top of the current screen that the gesture dismisses: the settings screen, or an
## overlay the screen itself opened (the Archive over the menu or the results screen; `Game.request_back` has closed
## that one already when it asks, through GameRunFlow.close_screen_overlay, and CLOSE_OVERLAY then has nothing left to
## do). It does NOT include the pause overlay itself, because in PAUSED the gesture means RESUME.
## A choice overlay of a generated run (salvage, draft, route, boss briefing) can never be dismissed: the gesture
## pauses, as in any run phase. (The upgrade drawer of the legacy HUD, its CLOSE_DRAWER action and the `drawer_open`
## and `choice_open` arguments went with the drawer in V5-A.)

enum Action { CLOSE_OVERLAY, PAUSE, RESUME, TO_MENU, CONFIRM_QUIT, NONE }


static func decide(state: int, overlay_open: bool) -> int:
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
			return Action.PAUSE  # also on a choice overlay: a choice is never dismissed
	return Action.NONE
