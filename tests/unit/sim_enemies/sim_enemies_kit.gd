class_name SimEnemiesKit
extends RefCounted
## Helpers for tests/unit/sim_enemies (task V4-N). Worlds come from TestContent.variety() only; enemies are placed by
## spawn_enemy and the systems are stepped directly, in the order of SimWorld.step.
##
## Call points in files V4-N does not own: three effects of this task enter the game through one call each in
## DamageResolver (the ward filter StatusSystem.absorb, the PLATED armor EliteSystem.armor_add, the body of `heal`) and
## one in DeathHooks (StatusSystem.on_enemy_killed). The probes below tell whether a call point exists in this checkout;
## `hit` and `kill` go through the real path when it does and otherwise make the same calls in the same order, so the
## behaviour tests hold before and after the call points are added. A test that can only pass through
## DamageResolver.heal asks `heal_wired` first.

const TOUGH_HP: float = 1.0e9

static var _probed: bool = false
static var _absorb: bool = false
static var _armor: bool = false
static var _heal: bool = false
static var _death: bool = false


## A variety world in a combat phase.
static func world(run_seed: int = 1) -> SimWorld:
	var w: SimWorld = TestContent.variety_world(run_seed)
	w.phase = GameState.Id.SPAWNING
	return w


## Spawns an enemy at an absolute position. Returns the store index.
static func place(w: SimWorld, type_index: int, x: float, z: float, affix_mask: int = 0) -> int:
	var i: int = w.spawn_enemy(type_index, x, z, affix_mask)
	w.enemies.path_dist[i] = w.nav.path_dist_of(w.enemies, i)
	return i


## Spawns an enemy at (dx, dz) from the core centre.
static func place_core(w: SimWorld, type_index: int, dx: float, dz: float, affix_mask: int = 0) -> int:
	return place(w, type_index, w.content.arena.core_x + dx, w.content.arena.core_z + dz, affix_mask)


## The affix mask of one or more affix ids.
static func mask(w: SimWorld, ids: Array[StringName]) -> int:
	var m: int = 0
	for id: StringName in ids:
		var at: int = w.content.affix_index(id)
		assert(at >= 0, "unknown affix " + String(id))
		m |= 1 << at
	return m


static func tough(w: SimWorld, index: int) -> void:
	w.enemies.hp[index] = TOUGH_HP
	w.enemies.max_hp[index] = TOUGH_HP


static func core_dist(w: SimWorld, index: int) -> float:
	var a: ArenaDef = w.content.arena
	return Vector2(w.enemies.x[index] - a.core_x, w.enemies.z[index] - a.core_z).length()


static func begin_tick(w: SimWorld) -> void:
	w.tick += 1
	w.events.current_tick = w.tick


## One tick of the enemy side of SimWorld.step, in its order: abilities (stun timers), statuses, movement, hazards,
## core attacks. No spawning, no weapons, no phases.
static func tick(w: SimWorld) -> void:
	begin_tick(w)
	AbilitySystem.step(w)
	StatusSystem.step(w)
	MovementSystem.step(w)
	HazardSystem.step(w)
	CoreAttackSystem.step(w)


static func run(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		tick(w)


## `tick` with SpawnSystem.step in its place (for waves).
static func tick_spawning(w: SimWorld) -> void:
	begin_tick(w)
	SpawnSystem.step(w)
	AbilitySystem.step(w)
	StatusSystem.step(w)
	MovementSystem.step(w)
	HazardSystem.step(w)
	CoreAttackSystem.step(w)


## Ticks until `index` is ST_ATTACKING (parked or in its slot) or `limit` ticks passed. Returns the ticks used, -1 = never.
static func run_until_attacking(w: SimWorld, index: int, limit: int = 3000) -> int:
	for n: int in limit:
		if w.enemies.state[index] == EnemyStore.ST_ATTACKING:
			return n
		tick(w)
	return -1


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


static func alive_of_type(w: SimWorld, type_index: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.type[i] == type_index:
			out.append(i)
	return out


## One hit through DamageResolver.hit_ex, wards and PLATED armor included (see the header). Returns the damage dealt.
static func hit(w: SimWorld, index: int, amount: float, flags: int = 0, source: int = DamageSource.Id.WARDEN) -> float:
	_probe()
	if _absorb and _armor:
		return DamageResolver.hit_ex(w, index, amount, flags, source)
	var raw: float = amount
	if (flags & DamageResolver.F_BURN) == 0:
		var armor: float = DamageResolver.effective_armor(w, index, flags)
		if not _armor and (flags & DamageResolver.F_IGNORE_ARMOR) == 0:
			var plating: float = EliteSystem.armor_add(w, index)
			armor += plating * (0.5 if (flags & DamageResolver.F_HALF_ARMOR) != 0 else 1.0)
		raw = maxf(1.0, raw - armor)
	if not _absorb:
		raw = StatusSystem.absorb(w, index, raw, flags)
	return DamageResolver.hit_ex(w, index, raw, flags | DamageResolver.F_BURN, source)


## Kills an enemy with everything its death causes (see the header).
static func kill(w: SimWorld, index: int, source: int = DamageSource.Id.WARDEN) -> void:
	_probe()
	if not _death:
		StatusSystem.on_enemy_killed(w, index, source)
	w.kill_enemy(index, source)


static func absorb_wired() -> bool:
	_probe()
	return _absorb


static func armor_wired() -> bool:
	_probe()
	return _armor


static func heal_wired() -> bool:
	_probe()
	return _heal


static func death_wired() -> bool:
	_probe()
	return _death


## Finds out, once, which call points this checkout has, on a scratch world.
static func _probe() -> void:
	if _probed:
		return
	_probed = true
	var w: SimWorld = world(77)
	var bearer: int = place_core(w, Ids.EN_SHIELDBEARER, 8.0, 0.0)
	var covered: int = place_core(w, Ids.EN_SKITTER, 9.0, 0.0)
	tough(w, covered)
	begin_tick(w)
	StatusSystem.step(w)
	_absorb = DamageResolver.hit_ex(w, covered, 100.0, DamageResolver.F_IGNORE_ARMOR, DeathHooks.SOURCE_SELF) < 99.0
	_heal = DamageResolver.heal(w, covered, 10.0) > 0.0
	var plated: int = place_core(w, Ids.EN_SKITTER, 12.0, 0.0, mask(w, [&"aff_plated"]))
	_armor = DamageResolver.effective_armor(w, plated, 0) > w.content.enemies[Ids.EN_SKITTER].armor
	var splitter: int = place_core(w, Ids.EN_SPLITTER, 10.0, 4.0)
	w.kill_enemy(splitter, DamageSource.Id.WARDEN)
	_death = not alive_of_type(w, Ids.EN_SHARD).is_empty()
	w.kill_enemy(bearer, DamageSource.Id.WARDEN)
