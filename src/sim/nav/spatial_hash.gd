class_name SpatialHash
extends RefCounted
## Uniform grid hash of enemy positions. TODO(W1-A).

@warning_ignore_start("unused_parameter")

func rebuild(store: EnemyStore) -> void:
	# TODO(W1-A)
	pass


## Fills `out` with store indices sorted by enemy id; returns the count.
func query(x: float, z: float, radius: float, out: PackedInt32Array) -> int:
	# TODO(W1-A)
	return 0
