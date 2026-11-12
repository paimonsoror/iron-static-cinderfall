class_name VarietyCKit
extends RefCounted
## Helpers for tests/unit/sim_arsenal (task V2-C). Worlds come from TestContent.variety() only. Enemies are placed by
## spawn_enemy and the systems are stepped directly, in the order of SimWorld.step, so these tests do not depend on
## movement, spawning or the phase flow (which other tasks of the wave change).

const TOUGH_HP: float = 1.0e9


## A variety world in a combat phase (the arsenal swap timer and crates only run during a wave).
static func world(run_seed: int = 1) -> SimWorld:
	var w: SimWorld = TestContent.variety_world(run_seed)
	w.phase = GameState.Id.SPAWNING
	return w


## Spawns an enemy at an absolute position. Returns the store index.
static func place(w: SimWorld, type_index: int, x: float, z: float, state: int = EnemyStore.ST_MOVING) -> int:
	var i: int = w.spawn_enemy(type_index, x, z)
	w.enemies.state[i] = state
	w.enemies.path_dist[i] = 100.0
	return i


## Spawns an enemy at the Warden's position plus (dx, dz).
static func place_rel(w: SimWorld, type_index: int, dx: float, dz: float) -> int:
	return place(w, type_index, w.warden.x + dx, w.warden.z + dz)


static func tough(w: SimWorld, index: int) -> void:
	w.enemies.hp[index] = TOUGH_HP
	w.enemies.max_hp[index] = TOUGH_HP


## Damage the enemy has taken since `tough`.
static func taken(w: SimWorld, index: int) -> float:
	return w.enemies.max_hp[index] - w.enemies.hp[index]


static func begin_tick(w: SimWorld) -> void:
	w.tick += 1
	w.events.current_tick = w.tick


static func weapon_tick(w: SimWorld) -> void:
	begin_tick(w)
	WeaponSystem.step(w)


static func run_weapon(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		weapon_tick(w)


static func hazard_tick(w: SimWorld) -> void:
	begin_tick(w)
	HazardSystem.step(w)


static func run_hazards(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		hazard_tick(w)


static func core_tick(w: SimWorld) -> void:
	begin_tick(w)
	CoreAttackSystem.step(w)


static func run_core(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		core_tick(w)


static func salvage_tick(w: SimWorld) -> void:
	begin_tick(w)
	SalvageSystem.step(w)


static func run_salvage(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		salvage_tick(w)


## One tick of the strike clock and the hazard queue (tick steps 4 and 11).
static func strike_tick(w: SimWorld) -> void:
	begin_tick(w)
	EventDeadfallStrike.sys_step(w)
	HazardSystem.step(w)


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


static func count(w: SimWorld, kind: int) -> int:
	return events_of(w, kind).size()


## The ticks of every event of `kind` so far.
static func ticks_of(w: SimWorld, kind: int) -> Array[int]:
	var out: Array[int] = []
	for e: SimEvent in events_of(w, kind):
		out.append(e.tick)
	return out


## The ticks at which the Warden fired, over `ticks` weapon ticks from now.
static func shot_ticks(w: SimWorld, ticks: int) -> Array[int]:
	var out: Array[int] = []
	for _n: int in ticks:
		var before: int = w.warden.shots_fired
		weapon_tick(w)
		if w.warden.shots_fired > before:
			out.append(w.tick)
	return out


## A swap as the command applies it: at the start of the next tick, before the weapon step of that tick.
static func swap_on_next_tick(w: SimWorld, slot: int) -> int:
	begin_tick(w)
	var reason: int = ArsenalSystem.swap(w, 1000 + w.tick, slot)
	WeaponSystem.step(w)
	return reason


## Puts a crate with known contents into the bank (a debug write: the real path rolls them from the crate stream).
static func bank(w: SimWorld, weapons: Array[int], boss: bool) -> void:
	w.salvage.banked.append(1 if boss else 0)
	for k: int in SalvageState.ITEMS_PER_CRATE:
		w.salvage.banked_items.append(weapons[k] if k < weapons.size() else -1)


# --- the 50 + 40 scenario of the determinism test and the micro-benchmark ---

const STRESS_TYPES: Array[int] = [Ids.EN_SKITTER, Ids.EN_BURSTER, Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_RUSHER]


## A world for whole-tick runs: the core cannot die, the Warden carries the pistol and the arc projector.
static func stress_world(run_seed: int) -> SimWorld:
	var cfg: SimConfig = SimConfig.create(TestContent.variety(), run_seed)
	cfg.debug_invulnerable_core = true
	var w: SimWorld = SimWorld.new(cfg)
	ArsenalSystem.give_weapon(w, 1, Ids.WP_ARC_PROJECTOR)
	return w


## One whole tick of the scenario: the field is topped up to 50 bodied enemies (enemy_cap) and 40 minis on the right edge,
## once a second the oldest burster is shot dead (a death blast, and the chain it starts) and the Warden swaps
## weapons, then SimWorld.step runs. Everything is a function of the world's own tick and counters.
static func stress_tick(w: SimWorld) -> void:
	stress_prepare(w)
	w.step()


static func stress_prepare(w: SimWorld) -> void:
	var arena: ArenaDef = w.content.arena
	var n: int = w.next_enemy_id
	var bodied: int = 0
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and not w.ext.has_flag(i, EnemyExtState.F_MINI):
			bodied += 1
	for _k: int in 4:
		var z: float = arena.min_z + 1.0 + fmod(float(n) * 2.37, arena.max_z - arena.min_z - 2.0)
		if bodied < w.content.mission.enemy_cap:
			var made: int = w.spawn_enemy(STRESS_TYPES[n % STRESS_TYPES.size()], arena.max_x - 1.0, z)
			if made < 0:
				made = w.spawn_enemy(Ids.EN_SKITTER, arena.max_x - 1.0, z)
			if made >= 0:
				bodied += 1
		w.spawn_enemy(Ids.EN_MOTE, arena.max_x - 1.5, arena.min_z + 1.0 + fmod(float(n) * 1.91, arena.max_z - arena.min_z - 2.0))
		n += 3
	if w.tick % 60 != 59:
		return
	var oldest: int = -1
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.type[i] == Ids.EN_BURSTER:
			if oldest < 0 or w.enemies.id[i] < w.enemies.id[oldest]:
				oldest = i
	if oldest >= 0:
		DamageResolver.hit_ex(w, oldest, TOUGH_HP, DamageResolver.F_IGNORE_ARMOR, DamageSource.Id.WARDEN)
	w.submit(SimCommand.swap_weapon(w.tick + 1, 1 - w.arsenal.active))
