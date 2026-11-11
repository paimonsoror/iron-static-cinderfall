class_name PhaseSystem
extends RefCounted
## Run phases and win/lose flow. TODO(W1-C).

@warning_ignore_start("unused_parameter")

## PREPARING with prepare_ticks.
static func init_world(world: SimWorld) -> void:
	# TODO(W1-C)
	pass


static func pre_step(world: SimWorld) -> void:
	# TODO(W1-C)
	pass


static func post_step(world: SimWorld) -> void:
	# TODO(W1-C)
	pass


## Returns a Reason.Id.
static func skip_intermission(world: SimWorld) -> int:
	# TODO(W1-C)
	return Reason.Id.WRONG_STATE
