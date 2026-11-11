class_name AbilitySystem
extends RefCounted
## EMP, shield, overdrive. TODO(W1-C).

@warning_ignore_start("unused_parameter")

## Returns a Reason.Id; pushes ABILITY_ACTIVATED or ABILITY_REJECTED.
static func activate(world: SimWorld, command_id: int, ability_index: int) -> int:
	# TODO(W1-C)
	return Reason.Id.WRONG_STATE


static func block_reason(world: SimWorld, ability_index: int) -> int:
	# TODO(W1-C)
	return Reason.Id.WRONG_STATE


static func step(world: SimWorld) -> void:
	# TODO(W1-C)
	pass
