class_name Targeting
extends RefCounted
## Target ranking. TODO(W1-B).

@warning_ignore_start("unused_parameter")

## Enemy id or 0.
static func pick(world: SimWorld, from_x: float, from_z: float, range_m: float) -> int:
	# TODO(W1-B)
	return 0


static func is_valid(world: SimWorld, enemy_id: int, from_x: float, from_z: float, range_m: float) -> bool:
	# TODO(W1-B)
	return false


## True if store index i outranks j.
static func compare(world: SimWorld, i: int, j: int, from_x: float, from_z: float) -> bool:
	# TODO(W1-B)
	return false
