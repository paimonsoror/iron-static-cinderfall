class_name NavSystemHooks
extends RefCounted
## The two entry points SimWorld calls into the nav module (ARCH 6.6).


## Called from SimWorld._init: builds the flow field, spatial hash, attack slots and per-enemy tables.
static func init_world(world: SimWorld) -> void:
	world.nav.setup(world)


## Releases the enemy's attack slot and drops its stuck tracker. Called by SimWorld.kill_enemy before the store
## slot is freed, so the slot is free again the same tick.
static func on_enemy_removed(world: SimWorld, enemy_index: int) -> void:
	var nav: NavState = world.nav
	nav.slots.release(world, enemy_index)
	nav.track_id[enemy_index] = 0
