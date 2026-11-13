class_name TurretRules
extends RefCounted
## The directive rules of the auto turrets (CONTENT 3), for TurretSystem and EventRates. The numbers that the `ops[]`
## grammar carries (`t_rate_mul`, `t_dmg_mul`, `t_inherit`, `range_mul`, the flag `od_turrets`) are read from ModState; the
## rules it cannot say live here:
##   sentry_link (t_inherit 0.5)  the turrets gain `t_inherit` x the Warden's damage level and fire-rate level from
##                                directives (hot_loads, cyclic_tuning), rounded down; the shop levels never reach them;
##   overwatch                    turrets take elites, spitters, reclaimers and jammers first and deal +40% to them;
##   mine_layer                   every 8 s (6 s at stack 2) a turret lays a mine 2 to 4 m from its pad toward the spawn
##                                edge, three per pad at most (HazardMines); the place is drawn from the `proc` stream.
## last_stand_protocol, Core Surge, the jammer aura and Overdrive (`od_turrets`) are rates: EventRates.turret_rate_milli.

const OVERWATCH_BONUS: float = 1.4
const MINE_PERIOD_TICKS: Array[int] = [480, 360]  ## stack 1 (8 s), stack 2 (6 s)
const MINE_MIN_M: float = 2.0
const MINE_MAX_M: float = 4.0
const MINE_SPREAD_RAD: float = 0.45
const PAD_OFFSET_TICKS: int = 97  ## pads lay on different ticks


## Turret range: the upgrade's own times ModState.range_mul.
static func range_of(world: SimWorld, def: UpgradeDef) -> float:
	return def.turret_range_m * world.mods.range_mul


## The damage level the turrets have from directives (sentry_link): floor(t_inherit x lvl_damage).
static func damage_level(world: SimWorld) -> int:
	return floori(world.mods.t_inherit * world.mods.lvl_damage + 0.000001)


## The fire-rate level the turrets have from directives (sentry_link): floor(t_inherit x lvl_fire_rate).
static func rate_level(world: SimWorld) -> int:
	return floori(world.mods.t_inherit * world.mods.lvl_fire_rate + 0.000001)


## True when overwatch is held.
static func overwatch(world: SimWorld) -> bool:
	return ModRules.held(world, &"overwatch") > 0


## An overwatch target: an elite, a spitter, a reclaimer or a jammer.
static func is_priority(world: SimWorld, enemy_index: int) -> bool:
	if world.ext.is_elite(enemy_index):
		return true
	var type_index: int = world.enemies.type[enemy_index]
	return type_index == Ids.EN_SPITTER or type_index == Ids.EN_RECLAIMER or type_index == Ids.EN_JAMMER


## The best-ranked overwatch target within `range_m` of (x, z), as an enemy id; 0 when there is none.
static func priority_target(world: SimWorld, x: float, z: float, range_m: float) -> int:
	var store: EnemyStore = world.enemies
	var best: int = -1
	for i: int in store.high_water:
		if store.alive[i] == 0 or not is_priority(world, i):
			continue
		if not Targeting.is_valid(world, store.id[i], x, z, range_m):
			continue
		if best < 0 or Targeting.compare(world, i, best, x, z):
			best = i
	return store.id[best] if best >= 0 else 0


## The factor on a turret's damage against enemy `enemy_index`: +40% on an overwatch target while overwatch is held.
static func damage_mul_vs(world: SimWorld, enemy_index: int, overwatch_held: bool) -> float:
	if overwatch_held and enemy_index >= 0 and is_priority(world, enemy_index):
		return OVERWATCH_BONUS
	return 1.0


## mine_layer: every pad that is active lays its mine when its period comes round (no state: the global tick decides).
static func lay_mines(world: SimWorld) -> void:
	var stacks: int = ModRules.held(world, &"mine_layer")
	if stacks <= 0 or world.content.arena.spawn_regions.is_empty():
		return
	var period: int = MINE_PERIOD_TICKS[mini(stacks, MINE_PERIOD_TICKS.size()) - 1]
	var t: TurretStore = world.turrets
	for pad: int in t.active.size():
		if t.active[pad] == 0 or (world.tick + pad * PAD_OFFSET_TICKS) % period != 0:
			continue
		if HazardMines.held_by(world, pad) >= HazardMines.cap(world):
			continue
		var edge: SpawnRegionDef = world.content.arena.spawn_regions[0]
		var toward: Vector2 = Vector2((edge.x0 + edge.x1) * 0.5 - t.x[pad], (edge.z0 + edge.z1) * 0.5 - t.z[pad]).normalized()
		var stream: RandomNumberGenerator = world.rng.stream(&"proc")
		var angle: float = toward.angle() + (stream.randf() * 2.0 - 1.0) * MINE_SPREAD_RAD
		var reach: float = lerpf(MINE_MIN_M, MINE_MAX_M, stream.randf())
		var nav: NavState = world.nav
		var x: float = clampf(t.x[pad] + cos(angle) * reach, nav.bound_min_x, nav.bound_max_x)
		var z: float = clampf(t.z[pad] + sin(angle) * reach, nav.bound_min_z, nav.bound_max_z)
		var _laid: bool = HazardMines.place(world, x, z, pad)
