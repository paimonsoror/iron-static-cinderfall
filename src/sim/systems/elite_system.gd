class_name EliteSystem
extends RefCounted
## Elites (VARIETY_SPEC 5.2, CONTENT 4.3): applies affixes at spawn, then the aura and leech rules each tick. Writes
## EnemyExtState.flags, affix_mask and hp_scale_milli. Pushes ELITE_SPAWNED(enemy id, affix mask).
# TODO(V2-A): the act tier in spawn_hp. TODO(V4-N): affixes.


## Hit points a newly spawned enemy starts with: the type's hp x the act tier x the elite and affix multipliers
## (a boss uses BossDef.hp). SimWorld.spawn_enemy calls it. The stub returns the plain value of the type.
static func spawn_hp(_world: SimWorld, def: EnemyDef, _affix_mask: int) -> float:
	return def.hp


## Marks store index `enemy_index` as an elite with `affix_mask`. SimWorld.spawn_enemy calls it for a mask != 0.
static func apply(_world: SimWorld, _enemy_index: int, _affix_mask: int) -> void:
	pass


## Living elites (the cap is RunDef.max_elites_alive).
static func alive_elites(world: SimWorld) -> int:
	var n: int = 0
	for i: int in world.enemies.high_water:
		if world.enemies.alive[i] == 1 and world.ext.is_elite(i):
			n += 1
	return n
