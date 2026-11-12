class_name GameRunFlow
extends RefCounted
## The variety entry points of `Game` (VARIETY_SPEC 13.4): how a run is launched with a kit and the profile's unlocks,
## the resume of a run that survived a process kill, and the Archive. `Game` keeps one-line delegates (its file is at
## the line cap); the logic lives here.
# TODO(V2-D): launch (kit, unlocks, daily seed) and resume. TODO(V4-U): the Archive overlay.

## What the next `Game.start_run` asked for; consumed by `apply_launch`.
static var pending_kit: StringName = &""
static var pending_daily: bool = false


## Remembers the kit and the daily flag of the run that is about to start.
static func set_launch(kit_id: StringName, daily: bool) -> void:
	pending_kit = kit_id
	pending_daily = daily


## Fills the variety fields of a new run's SimConfig (kit_index, unlocked, daily) from the pending launch and clears it.
## An unknown or empty kit is the standard kit (index 0). The profile's unlock list is added by V2-D with profile v2.
static func apply_launch(config: SimConfig, content: ContentSet) -> void:
	config.kit_index = maxi(0, content.kit_index(pending_kit))
	config.daily = pending_daily
	pending_kit = &""
	pending_daily = false


## RESUME RUN: restores the run file and starts it. False when there is nothing to resume (the stub: always).
static func resume_from_disk(_game: Node) -> bool:
	return false


## Opens the Archive as an overlay on the menu. False when it could not be shown (the stub: always).
static func open_archive(_game: Node) -> bool:
	return false
