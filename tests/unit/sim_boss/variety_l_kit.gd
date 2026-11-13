class_name VarietyLKit
extends RefCounted
## Helpers for tests/unit/sim_boss (task V4-L). Worlds come from TestContent.variety() only. A boss is placed by
## spawn_enemy and the systems its script meets are stepped directly, in the order of SimWorld.step, so these tests do
## not depend on the spawn schedule or the phase flow. `tick` leaves movement out (a boss stands where it was placed);
## `tick_move` adds MovementSystem for the tests about walking.
## Core at (-7.5, 3.0), cage radius 2.0, approach circle 9.0, 1000 hp.

const CORE_X: float = -7.5
const CORE_Z: float = 3.0
## A spot 15.5 m from the core, outside the approach circle and clear of the props.
const FAR_X: float = 8.0
const FAR_Z: float = 3.0
const TOUGH_HP: float = 1.0e9


## The variety content with a boss entry for each of the five bosses in its act pool (brood carrier and lance platform
## act I, aegis array and tremor rig act II, the siege hulk act III), no behaviour numbers (the scripts' fallbacks are
## the values of CONTENT 5).
static func pool_content() -> ContentSet:
	var c: ContentSet = TestContent.variety()
	c.bosses.clear()
	c.bosses.append(_boss(c, Ids.EN_BROOD_CARRIER, 1))
	c.bosses.append(_boss(c, Ids.EN_LANCE_PLATFORM, 1))
	c.bosses.append(_boss(c, Ids.EN_AEGIS_ARRAY, 2))
	c.bosses.append(_boss(c, Ids.EN_TREMOR_RIG, 2))
	c.bosses.append(_boss(c, Ids.EN_HULK, 3))
	return c


static func _boss(c: ContentSet, enemy_index: int, pool_act: int) -> BossDef:
	var b: BossDef = BossDef.new()
	b.id = c.enemies[enemy_index].id
	b.enemy_index = enemy_index
	b.name_key = "boss.%s.name" % b.id
	b.banner_key = "boss.%s.banner" % b.id
	b.pool_act = pool_act
	b.hp = c.enemies[enemy_index].hp
	b.escort_enemy = PackedInt32Array([Ids.EN_SKITTER])
	b.escort_share = PackedFloat32Array([1.0])
	return b


## A variety world in a combat phase. `content` null = the frozen fixture as it is.
static func world(run_seed: int = 1, content: ContentSet = null) -> SimWorld:
	var w: SimWorld = SimWorld.new(SimConfig.create(content if content != null else TestContent.variety(), run_seed))
	w.phase = GameState.Id.SPAWNING
	return w


## Spawns a body at (x, z) between two ticks. Returns the store index.
static func place(w: SimWorld, type_index: int, x: float = FAR_X, z: float = FAR_Z) -> int:
	return w.spawn_enemy(type_index, x, z)


## A Node 9 of the last act with variant `variant_id` (the plan's variant is set by hand: a debug write).
static func place_hulk(w: SimWorld, variant_id: StringName, x: float = FAR_X, z: float = FAR_Z) -> int:
	w.phase_state.act = w.content.run.acts.size()
	w.plan.boss_variant = w.content.run.hulk_variants.find(variant_id)
	return place(w, Ids.EN_HULK, x, z)


static func begin_tick(w: SimWorld) -> void:
	w.tick += 1
	w.events.current_tick = w.tick


## The rest of a tick after the command step: abilities (stun timers), core attacks, the boss script.
static func finish_tick(w: SimWorld, move: bool = false) -> void:
	AbilitySystem.step(w)
	if move:
		MovementSystem.step(w)
	CoreAttackSystem.step(w)
	BossSystem.step(w)


static func tick(w: SimWorld) -> void:
	begin_tick(w)
	finish_tick(w)


static func run(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		tick(w)


## Steps until `w.tick == target`.
static func run_to(w: SimWorld, target: int) -> void:
	while w.tick < target:
		tick(w)


static func tick_move(w: SimWorld) -> void:
	begin_tick(w)
	finish_tick(w, true)


static func run_move(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		tick_move(w)


## One tick whose command step activates `ability` (as CommandSystem does it, before every other system).
static func tick_with_ability(w: SimWorld, ability: int, move: bool = false) -> int:
	begin_tick(w)
	var reason: int = AbilitySystem.activate(w, 900000 + w.tick, ability)
	finish_tick(w, move)
	return reason


## Sets the hit points of a body to `frac` of its maximum (a debug write).
static func set_hp_frac(w: SimWorld, index: int, frac: float) -> void:
	w.enemies.hp[index] = w.enemies.max_hp[index] * frac


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


## The ticks of every BOSS_TELEGRAPH of `attack` so far.
static func telegraph_ticks(w: SimWorld, attack: int) -> Array[int]:
	var out: Array[int] = []
	for e: SimEvent in events_of(w, SimEventKind.Id.BOSS_TELEGRAPH):
		if e.a == attack:
			out.append(e.tick)
	return out


## The ticks at which a body of `type_index` spawned, one entry per tick.
static func spawn_ticks(w: SimWorld, type_index: int) -> Array[int]:
	var out: Array[int] = []
	for e: SimEvent in events_of(w, SimEventKind.Id.ENEMY_SPAWNED):
		if e.b == type_index and (out.is_empty() or out[out.size() - 1] != e.tick):
			out.append(e.tick)
	return out


## The ticks of every CORE_HIT so far.
static func core_hit_ticks(w: SimWorld) -> Array[int]:
	var out: Array[int] = []
	for e: SimEvent in events_of(w, SimEventKind.Id.CORE_HIT):
		out.append(e.tick)
	return out


## The (phase, phase count) pairs of every BOSS_PHASE so far.
static func phases(w: SimWorld) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e: SimEvent in events_of(w, SimEventKind.Id.BOSS_PHASE):
		out.append(Vector2i(e.a, e.b))
	return out


## Store indices of the living bodies of `type_index`, in store order.
static func living(w: SimWorld, type_index: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.type[i] == type_index:
			out.append(i)
	return out


## Removes every living body of `type_index` (nobody's kill).
static func cull(w: SimWorld, type_index: int) -> void:
	for i: int in living(w, type_index):
		w.kill_enemy(i, DeathHooks.SOURCE_SELF)


static func dist_to_core(w: SimWorld, index: int) -> float:
	return Vector2(w.enemies.x[index] - CORE_X, w.enemies.z[index] - CORE_Z).length()


## A snapshot of `w` through JSON text and back into a new world of the same content and seed (resume).
static func resumed(w: SimWorld) -> SimWorld:
	var text: String = JSON.stringify(WorldSnapshot.capture(w))
	var doc: Dictionary = JSON.parse_string(text)
	var back: SimWorld = SimWorld.new(SimConfig.create(w.content, w.config.run_seed))
	if not WorldSnapshot.restore(back, doc):
		return null
	return back
