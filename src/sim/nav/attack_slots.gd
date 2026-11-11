class_name AttackSlots
extends RefCounted
## Attack slots on rings around the core. TODO(W1-A).

@warning_ignore_start("unused_parameter")

## Lowest ring with a free run of `slot_span`; nearest in ring; tie -> lower index. -1 = none.
func claim(world: SimWorld, enemy_index: int) -> int:
	# TODO(W1-A)
	return -1


func release(world: SimWorld, enemy_index: int) -> void:
	# TODO(W1-A)
	pass


## Enemy id in the slot, or 0.
func occupant(slot_index: int) -> int:
	# TODO(W1-A)
	return 0
