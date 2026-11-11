class_name SpawnSystem
extends RefCounted
## Scheduled spawns and the pending queue. TODO(W1-A).

@warning_ignore_start("unused_parameter")

## Builds the tick-ordered schedule (group order, ordinal).
static func begin_wave(world: SimWorld, wave_index: int) -> void:
	# TODO(W1-A)
	pass


static func step(world: SimWorld) -> void:
	# TODO(W1-A)
	pass


## Schedule exhausted AND pending queue empty.
static func is_wave_fully_spawned(world: SimWorld) -> bool:
	# TODO(W1-A)
	return false


static func pending_count(world: SimWorld) -> int:
	# TODO(W1-A)
	return 0
