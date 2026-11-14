class_name DirectiveKit
extends RefCounted
## Helpers of the V4-C suites (the 60 directives, their hooks, the packs, modifiers, kits and plan patches). Content is
## always the frozen variety fixture (WORK_PLAN rule 5); worlds are put in a combat phase and the systems under test are
## called directly, so these tests do not depend on movement, spawning or the phase flow.

const CORE_X: float = -7.5
const CORE_Z: float = 3.0


## Every unlock of `c` that opens content (weapons, directive packs, kits) and none of the field options: the full pool
## without the free reroll, the third sling and the turret types, so a directive test measures the directive.
static func content_unlocks(c: ContentSet) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for u: UnlockDef in c.unlocks:
		if u.branch != UnlockDef.Branch.FIELD:
			out.append(String(u.id))
	out.sort()
	return out


## A variety world on the fixture (or on `c`) in a combat phase of wave `wave_number`, act `act`. The full content pool is
## open (`content_unlocks`) so any directive can be offered; picks go through DraftSystem.grant_stack either way.
static func world(run_seed: int = 1, wave_number: int = 3, act: int = 1, c: ContentSet = null) -> SimWorld:
	var cfg: SimConfig = SimConfig.create(c if c != null else TestContent.variety(), run_seed)
	cfg.unlocked = content_unlocks(cfg.content)
	var w: SimWorld = SimWorld.new(cfg)
	w.phase = GameState.Id.SPAWNING
	w.wave = wave_number
	w.phase_state.act = act
	return w


## Takes `stacks` stacks of directive `id` the way a pick does (stacks, recompute, GRANT ops, plan patch).
static func give(w: SimWorld, id: StringName, stacks: int = 1) -> void:
	var index: int = w.content.directive_index(id)
	assert(index >= 0)
	for _n: int in stacks:
		var _ok: bool = DraftSystem.grant_stack(w, index)


static func held(w: SimWorld, id: StringName) -> int:
	return w.draft.stacks_of(w.content.directive_index(id))


## Spawns an enemy at an absolute position in `state`; returns the store index.
static func place(w: SimWorld, type_index: int, x: float, z: float, state: int = EnemyStore.ST_MOVING) -> int:
	var i: int = w.spawn_enemy(type_index, x, z)
	w.enemies.state[i] = state
	w.enemies.path_dist[i] = 100.0
	return i


## An enemy in an attack slot of the core.
static func attacker(w: SimWorld, type_index: int = Ids.EN_SKITTER) -> int:
	return place(w, type_index, CORE_X + 3.5, CORE_Z, EnemyStore.ST_ATTACKING)


static func begin_tick(w: SimWorld) -> void:
	w.tick += 1
	w.events.current_tick = w.tick


## Sets hp (and max) of an enemy so a test can count damage.
static func set_hp(w: SimWorld, index: int, hp: float) -> void:
	w.enemies.hp[index] = hp
	w.enemies.max_hp[index] = hp


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


static func stack_hash(w: SimWorld) -> String:
	return w.state_hash()


## A KitDef built from ops (the six kits of CONTENT 11 live in data/unlocks.json, which task V4-M owns; the tests spell the
## ops out here so the sim side is covered whatever that file holds). Appended to `c.kits`; returns its index.
static func add_kit(c: ContentSet, id: StringName, ops: Array[OpDef]) -> int:
	var kit: KitDef = KitDef.new()
	kit.id = id
	kit.index = c.kits.size()
	kit.name_key = "kit.%s.name" % String(id)
	kit.ops = ops
	c.kits.append(kit)
	return kit.index


## A world whose run uses kit `kit_index` of `c`.
static func kit_world(c: ContentSet, kit_index: int, run_seed: int = 1) -> SimWorld:
	var cfg: SimConfig = SimConfig.create(c, run_seed)
	cfg.kit_index = kit_index
	cfg.unlocked = content_unlocks(c)
	return SimWorld.new(cfg)


## The six kits of CONTENT 11 as ops (the standard kit is empty).
static func kit_ops(id: StringName) -> Array[OpDef]:
	var ops: Array[OpDef] = []
	match id:
		&"k_breacher":
			ops = [
				VarietyBKit.op_grant(&"weapon", 1.0, &"scattergun"), VarietyBKit.op_grant(&"turret", 1.0),
				VarietyBKit.op_add(&"core_max_mul", -0.15),
			]
		&"k_signal":
			ops = [
				VarietyBKit.op_grant(&"event_charge", 1.0, &"deadfall_strike"), VarietyBKit.op_add(&"emp_cd_mul", -0.20),
				VarietyBKit.op_flag(&"no_turret_pity"),
			]
		&"k_gunline":
			ops = [VarietyBKit.op_grant(&"turret", 2.0), VarietyBKit.op_add(&"w_dmg_mul", -0.25)]
		&"k_ledger":
			ops = [
				VarietyBKit.op_grant(&"scrap", 400.0), VarietyBKit.op_grant(&"free_reroll", 2.0),
				VarietyBKit.op_add(&"core_max_mul", -0.10),
			]
		&"k_gambler":
			ops = [
				VarietyBKit.op_grant(&"directive_random", 1.0, &"corrupted"),
				VarietyBKit.op_grant(&"directive_random", 1.0, &"prototype"),
			]
	return ops


## Hash of one state object through hash_into.
static func hash_of(state: Object) -> String:
	var h: StateHasher = StateHasher.new()
	state.call("hash_into", h)
	return h.finish()
