class_name DeathHooks
extends RefCounted
## What a death causes (VARIETY_SPEC 13.2): burster and volatile blasts (queued with the chain delay, never
## recursion), splits, crate credit, kill hooks of directives. SimWorld.kill_enemy calls both functions before the
## store slot is freed, so position, type and ext state of the dying enemy can still be read.
# TODO(V4-C): the HOOK directives of CONTENT 3. TODO(V4-N): split, jammer, the VOLATILE affix.

## The `source` of a death nobody on the player's side caused: a mini that burns out on the cage, a burster whose
## fuse ends. It pays no Scrap and is not tallied by DamageSource.
const SOURCE_SELF: int = -1
## Ticks between a death and its blast when the type does not say (`chain_delay_ticks`).
const CHAIN_DELAY_TICKS: int = 6


## The Scrap this kill pays: the type's value x ModState.scrap_mul x the elite multiplier x the relay-window
## multiplier, rounded; 0 for SOURCE_SELF. The legacy content pays the plain value of the type.
static func scrap_for(world: SimWorld, enemy_index: int, source: int) -> int:
	var base: int = world.content.enemies[world.enemies.type[enemy_index]].scrap
	var run: RunDef = world.content.run
	if run == null:
		return base
	if source == SOURCE_SELF:
		return 0
	var mult: float = world.mods.scrap_mul
	if world.ext.is_elite(enemy_index):
		mult *= run.elite_scrap_mult
	if world.events_state.scrap_mult_ticks > 0:
		mult *= float(world.events_state.scrap_mult_milli) / 1000.0
	return maxi(0, roundi(float(base) * mult))


static func on_killed(world: SimWorld, enemy_index: int, source: int) -> void:
	if world.content.run == null:
		return
	var store: EnemyStore = world.enemies
	var type_index: int = store.type[enemy_index]
	var def: EnemyDef = world.content.enemies[type_index]
	var x: float = store.x[enemy_index]
	var z: float = store.z[enemy_index]
	var radius: float = def.beh(&"death_blast_radius")
	if radius > 0.0:
		var core_part: float = 0.0
		if source != SOURCE_SELF and _near_cage(world, x, z, def.beh(&"death_blast_core_range")):
			core_part = def.beh(&"death_blast_core") * CoreAttackSystem.core_mult(world)
		_queue(world, def, x, z, radius, def.beh(&"death_blast_damage"), def.beh(&"death_blast_edge", 1.0), core_part)
	elif type_index == Ids.EN_SKITTER and world.mods.has_flag(&"volatile_skitters") and world.mods.volatile_radius > 0.0:
		_queue(world, def, x, z, world.mods.volatile_radius, world.mods.volatile_damage, 1.0, 0.0)
	SalvageSystem.on_enemy_killed(world, enemy_index, source)


## A death blast: it lands `chain_delay_ticks` after the death, hurts enemies only (armor applies), and its kills
## count for the source HAZARD.
static func _queue(
	world: SimWorld, def: EnemyDef, x: float, z: float, radius: float, damage: float, edge: float, core_part: float
) -> void:
	var delay: int = maxi(1, roundi(def.beh(&"chain_delay_ticks", float(CHAIN_DELAY_TICKS))))
	HazardSystem.queue_blast(
		world, world.tick + delay, HazardState.K_BLAST, x, z, radius, damage, edge, DamageResolver.F_AREA,
		DamageSource.Id.HAZARD, core_part, def.index
	)


## True when (x, z) is within `range_m` of the core cage (the circle of core_radius).
static func _near_cage(world: SimWorld, x: float, z: float, range_m: float) -> bool:
	if range_m <= 0.0:
		return false
	var arena: ArenaDef = world.content.arena
	var dx: float = x - arena.core_x
	var dz: float = z - arena.core_z
	var reach: float = arena.core_radius + range_m
	return dx * dx + dz * dz <= reach * reach
