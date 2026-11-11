class_name BackPolicy
extends RefCounted
## What the Android back gesture does in each state (pure). TODO(W2-A): the real table.

@warning_ignore_start("unused_parameter")

enum Action { CLOSE_OVERLAY, CLOSE_DRAWER, PAUSE, RESUME, TO_MENU, CONFIRM_QUIT, NONE }


static func decide(state: int, drawer_open: bool, overlay_open: bool) -> int:
	# TODO(W2-A)
	return Action.NONE
