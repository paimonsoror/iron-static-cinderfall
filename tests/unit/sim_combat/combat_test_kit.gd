class_name CombatTestKit
extends RefCounted
## Helpers for tests/unit/sim_combat. Worlds come from TestContent.baseline() only. Enemies are placed by
## writing the store directly and the combat systems are stepped directly (never SimWorld.step), so these
## tests do not depend on movement, spawning or phases.

const TOUGH_HP: float = 1.0e9
const MILLI_PER_SHOT: int = 60000


static func world(run_seed: int = 1) -> SimWorld:
	return TestContent.world(run_seed)


## Spawns an enemy at the Warden's position plus (dx, dz) and sets its state and path_dist. Returns the store index.
static func place(
	w: SimWorld, type_index: int, dx: float, dz: float, state: int = EnemyStore.ST_MOVING, path_dist: float = 0.0
) -> int:
	return place_abs(w, type_index, w.warden.x + dx, w.warden.z + dz, state, path_dist)


static func place_abs(
	w: SimWorld, type_index: int, x: float, z: float, state: int = EnemyStore.ST_MOVING, path_dist: float = 0.0
) -> int:
	var i: int = w.spawn_enemy(type_index, x, z)
	w.enemies.state[i] = state
	w.enemies.path_dist[i] = path_dist
	return i


## Gives the enemy an effectively unlimited hp so shots never kill it.
static func make_tough(w: SimWorld, index: int) -> void:
	w.enemies.hp[index] = TOUGH_HP
	w.enemies.max_hp[index] = TOUGH_HP


static func activate_turret(w: SimWorld, pad: int) -> void:
	w.turrets.active[pad] = 1


static func begin_tick(w: SimWorld) -> void:
	w.tick += 1
	w.events.current_tick = w.tick


## One tick of the Warden system only.
static func warden_tick(w: SimWorld) -> void:
	begin_tick(w)
	WeaponSystem.step(w)


## One tick of the turret system only.
static func turret_tick(w: SimWorld) -> void:
	begin_tick(w)
	TurretSystem.step(w)


## One tick of core attacks only.
static func core_tick(w: SimWorld) -> void:
	begin_tick(w)
	CoreAttackSystem.step(w)


## One tick of all combat systems in SimWorld.step order (Warden, turrets, core attacks).
static func combat_tick(w: SimWorld) -> void:
	begin_tick(w)
	WeaponSystem.step(w)
	TurretSystem.step(w)
	CoreAttackSystem.step(w)


static func run_warden(w: SimWorld, ticks: int) -> void:
	for n: int in ticks:
		warden_tick(w)


static func run_core(w: SimWorld, ticks: int) -> void:
	for n: int in ticks:
		core_tick(w)


static func run_turrets(w: SimWorld, ticks: int) -> void:
	for n: int in ticks:
		turret_tick(w)


static func run_combat(w: SimWorld, ticks: int) -> void:
	for n: int in ticks:
		combat_tick(w)


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


static func count(w: SimWorld, kind: int) -> int:
	return events_of(w, kind).size()


## The ticks at which the Warden's shots_fired counter rose, over `ticks` Warden ticks from now.
static func warden_shot_ticks(w: SimWorld, ticks: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for n: int in ticks:
		var before: int = w.warden.shots_fired
		warden_tick(w)
		if w.warden.shots_fired > before:
			out.append(w.tick)
	return out


## Model of the ARCH 6.5 cadence rule for a shooter that always has a target: each tick accumulate, fire
## while the accumulator holds a shot and the magazine is not empty and no reload runs, clamp to one shot.
## A reload of `reload_ticks` starts with the last round and may be followed by a shot on the tick it ends.
static func model_shots(sps_milli: int, magazine: int, reload_ticks: int, ticks: int) -> int:
	var acc: int = 0
	var rounds: int = magazine
	var reload: int = 0
	var shots: int = 0
	for n: int in ticks:
		if reload > 0:
			reload -= 1
			if reload == 0:
				rounds = magazine
		acc += sps_milli
		while acc >= MILLI_PER_SHOT and reload == 0 and rounds > 0:
			acc -= MILLI_PER_SHOT
			rounds -= 1
			shots += 1
			if rounds == 0:
				reload = reload_ticks
		if acc > MILLI_PER_SHOT:
			acc = MILLI_PER_SHOT
	return shots
