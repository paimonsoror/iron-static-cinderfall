class_name NavState
extends RefCounted
## Navigation state owned by the nav systems: FlowField, SpatialHash, AttackSlots, spawn schedule,
## pending queue, stuck trackers. TODO(W1-A) adds the fields and hashes them.

@warning_ignore_start("unused_parameter")

func hash_into(h: StateHasher) -> void:
	# TODO(W1-A)
	pass
