class_name CommandSystem
extends RefCounted
## Applies queued commands in submission order. TODO(W1-C).
## The stub leaves world.command_queue untouched.

@warning_ignore_start("unused_parameter")

## Dedups command_id (DUPLICATE_COMMAND); one PURCHASE per upgrade per tick; logs applied commands with their tick.
static func apply_queued(world: SimWorld) -> void:
	# TODO(W1-C)
	pass
