class_name PhaseState
extends RefCounted
## State owned by the flow systems (ARCH 6.6 "Economy, abilities, flow"): PhaseSystem and CommandSystem write it.
## Everything here affects outcomes, so everything is hashed.

## Intermission sub-steps (VARIETY_SPEC 2.5). While `awaiting != NONE` SimWorld.step() only applies queued commands:
## the tick does not advance and no timer runs. RunApi mirrors these values as AWAIT_* for the UI. Append only.
enum Await { NONE, SALVAGE, DRAFT, ROUTE, BOSS_BRIEF }

## Debug and test hook: while true, PhaseSystem treats the current wave as fully spawned (the SPAWNING to CLEARING
## condition) without asking SpawnSystem. Production code never sets it.
var force_wave_spawned: bool = false

## RUN_FINISHED has been pushed. It is pushed exactly once per run.
var run_finished: bool = false

## Every command_id CommandSystem has dequeued, in first-seen order (idempotency: a repeat is DUPLICATE_COMMAND).
var seen_command_ids: Dictionary[int, bool] = {}

# --- variety milestone (VARIETY_SPEC 2.5); TODO(V2-A): PhaseSystem drives them ---
var awaiting: int = Await.NONE
var act: int = 1  ## 1..3
var breather: bool = false  ## true while INTERMISSION counts breather_ticks


func has_seen(command_id_value: int) -> bool:
	return seen_command_ids.has(command_id_value)


func mark_seen(command_id_value: int) -> void:
	seen_command_ids[command_id_value] = true


func hash_into(h: StateHasher) -> void:
	h.put_int(1 if force_wave_spawned else 0)
	h.put_int(1 if run_finished else 0)
	h.put_int(seen_command_ids.size())
	for command_id_value: int in seen_command_ids:
		h.put_int(command_id_value)
	h.put_int(awaiting)
	h.put_int(act)
	h.put_int(1 if breather else 0)
