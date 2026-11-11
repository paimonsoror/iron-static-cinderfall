class_name NavSystemHooks
extends RefCounted
## Called by SimWorld. TODO(W1-A).

@warning_ignore_start("unused_parameter")

## Called from SimWorld._init.
static func init_world(world: SimWorld) -> void:
	# TODO(W1-A)
	pass


## Releases the enemy's attack slot. Called by SimWorld.kill_enemy before the store slot is freed.
static func on_enemy_removed(world: SimWorld, enemy_index: int) -> void:
	# TODO(W1-A)
	pass
