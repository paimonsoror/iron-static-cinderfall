class_name DeathHooks
extends RefCounted
## What a death causes (VARIETY_SPEC 13.2): burster and volatile blasts (queued with the chain delay, never
## recursion), splits, crate credit, kill hooks of directives. SimWorld.kill_enemy calls both functions before the
## store slot is freed, so position, type and ext state of the dying enemy can still be read.
# TODO(V2-C): burster blast, crate credit. TODO(V4-C): the HOOK directives of CONTENT 3. TODO(V4-N): split, jammer.


## The Scrap this kill pays (ModState.scrap_mul, elite and relay-window multipliers; minis that burn out pay 0).
## The stub pays the plain value of the type, as before the variety milestone.
static func scrap_for(world: SimWorld, enemy_index: int, _source: int) -> int:
	return world.content.enemies[world.enemies.type[enemy_index]].scrap


static func on_killed(_world: SimWorld, _enemy_index: int, _source: int) -> void:
	pass
