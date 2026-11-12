class_name PolicySenses
extends RefCounted
## What a bot may read from the world (VARIETY_SPEC 14.1): pure functions of the state, no side effects, no random
## stream. Every count loops the enemy store in index order, so the answers are the same on every machine.


## Core integrity left, 0..1.
static func core_fraction(world: SimWorld) -> float:
	return world.core_hp / maxf(world.core_max_hp, 1.0)


## Enemies standing in an attack slot (ST_ATTACKING).
static func attackers(world: SimWorld) -> int:
	var store: EnemyStore = world.enemies
	var n: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 1 and store.state[i] == EnemyStore.ST_ATTACKING:
			n += 1
	return n


## Living enemies within `radius_m` of the core.
static func near_core(world: SimWorld, radius_m: float) -> int:
	var store: EnemyStore = world.enemies
	var cx: float = world.content.arena.core_x
	var cz: float = world.content.arena.core_z
	var limit: float = radius_m * radius_m
	var n: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		var dx: float = store.x[i] - cx
		var dz: float = store.z[i] - cz
		if dx * dx + dz * dz <= limit:
			n += 1
	return n


## The most enemies found within `radius_m` of any one living enemy (that enemy included): the size of the densest
## cluster. O(n^2) in the living enemies, so callers scan it every few ticks, never every tick.
static func densest(world: SimWorld, radius_m: float) -> int:
	var store: EnemyStore = world.enemies
	var limit: float = radius_m * radius_m
	var best: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		var n: int = 0
		for j: int in store.high_water:
			if store.alive[j] == 0:
				continue
			var dx: float = store.x[j] - store.x[i]
			var dz: float = store.z[j] - store.z[i]
			if dx * dx + dz * dz <= limit:
				n += 1
		best = maxi(best, n)
	return best


## Two living elites within `radius_m` of each other.
static func elite_pair(world: SimWorld, radius_m: float) -> bool:
	var store: EnemyStore = world.enemies
	var limit: float = radius_m * radius_m
	for i: int in store.high_water:
		if store.alive[i] == 0 or not world.ext.is_elite(i):
			continue
		for j: int in range(i + 1, store.high_water):
			if store.alive[j] == 0 or not world.ext.is_elite(j):
				continue
			var dx: float = store.x[j] - store.x[i]
			var dz: float = store.z[j] - store.z[i]
			if dx * dx + dz * dz <= limit:
				return true
	return false


## The boss is alive and the Warden's current weapon reaches it.
static func boss_in_range(world: SimWorld) -> bool:
	var i: int = world.boss_store_index()
	if i < 0:
		return false
	var dx: float = world.enemies.x[i] - world.warden.x
	var dz: float = world.enemies.z[i] - world.warden.z
	var reach: float = world.content.weapons[world.warden.weapon_index].range_m
	return dx * dx + dz * dz <= reach * reach


## A boss attack is being telegraphed right now (BossState).
static func boss_telegraphing(world: SimWorld) -> bool:
	return world.boss.telegraph_attack >= 0 and world.boss.telegraph_left > 0


## The telegraphed attack belongs to a lance platform (the beam a Shield should be up for).
static func lance_beam_coming(world: SimWorld) -> bool:
	return boss_telegraphing(world) and world.boss.boss_type == Ids.EN_LANCE_PLATFORM


## The route step (or a plan lookup) of the wave that starts next: `world.wave` stays at the cleared wave through
## the intermission (PhaseSystem), so the next wave is `wave + 1`.
static func next_wave(world: SimWorld) -> int:
	return world.wave + 1
