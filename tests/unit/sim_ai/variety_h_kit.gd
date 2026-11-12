class_name VarietyHKit
extends RefCounted
## Hand-made states for the bot suites of V2-H (tests/unit/sim_ai). The sim systems that make real awaits, offers and
## crates belong to V2-A, V2-B and V2-C; the bots are tested here on states written by hand, so the suites stay valid
## whether those systems are still stubs or already real. Content: TestContent.variety() (WORK_PLAN rule 5).


## The variety fixture, parsed once for the whole run of the suites: reading the JSON dominates the cost of a world,
## and the bot suites only read the content (a test that changes it must build its own with TestContent.variety()).
static var _content: ContentSet = null


static func content() -> ContentSet:
	if _content == null:
		_content = TestContent.variety()
	return _content


static func world(run_seed: int = 1) -> SimWorld:
	return SimWorld.new(SimConfig.create(content(), run_seed))


## A variety world that waits for the choice `kind` (PhaseState.Await.*), in the intermission after wave `wave_number`.
static func awaiting(kind: int, wave_number: int = 2, run_seed: int = 1) -> SimWorld:
	var w: SimWorld = world(run_seed)
	w.set_phase(GameState.Id.SPAWNING)
	w.set_phase(GameState.Id.CLEARING)
	w.set_phase(GameState.Id.INTERMISSION)
	w.wave = wave_number
	w.phase_state.awaiting = kind
	return w


static func directive(w: SimWorld, id: StringName) -> int:
	return w.content.directive_index(id)


static func weapon(id: StringName) -> int:
	return Ids.WEAPONS.find(id)


## Opens a draft showing `ids` (-1 entries are taken slots).
static func offer(w: SimWorld, ids: Array[StringName]) -> void:
	var slots: PackedInt32Array = PackedInt32Array()
	for id: StringName in ids:
		slots.append(w.content.directive_index(id) if id != &"" else -1)
	w.draft.offer = slots
	w.draft.open = true
	w.draft.offer_ordinal = maxi(1, w.draft.offer_ordinal)
	w.phase_state.awaiting = PhaseState.Await.DRAFT


static func hold(w: SimWorld, id: StringName, stacks: int) -> void:
	w.draft.stacks[w.content.directive_index(id)] = stacks


## Puts `weapon_id` into `slot` at `level` (the arsenal stub of V1-S holds the pistol in slot 0).
static func carry(w: SimWorld, slot: int, weapon_id: StringName, level: int = 1) -> void:
	w.arsenal.slot_weapon[slot] = Ids.WEAPONS.find(weapon_id)
	w.arsenal.slot_level[slot] = level


## Opens a salvage step showing the crate `weapon_ids` (two for a boss crate).
static func crate(w: SimWorld, weapon_ids: Array[StringName]) -> void:
	var offered: PackedInt32Array = PackedInt32Array()
	for id: StringName in weapon_ids:
		offered.append(Ids.WEAPONS.find(id))
	w.salvage.offer = offered
	w.salvage.offer_boss = weapon_ids.size() > 1
	w.phase_state.awaiting = PhaseState.Await.SALVAGE


## A route option on `pack_id` with `reward_id`.
static func option(w: SimWorld, pack_id: StringName, reward_id: StringName, hot: bool) -> RouteOption:
	var o: RouteOption = RouteOption.new()
	o.pack_index = w.content.run.pack_index(pack_id)
	o.reward_index = w.content.run.reward_index(reward_id)
	o.hot = hot
	return o


## Replaces the options of `wave_number` in the plan and opens the route step for it (the wave before it is the one
## just cleared).
static func route(w: SimWorld, wave_number: int, options: Array[RouteOption]) -> void:
	var planned: PlannedWave = w.plan.wave(wave_number)
	planned.options = options
	w.wave = wave_number - 1
	w.phase_state.awaiting = PhaseState.Await.ROUTE


## `n` living skitters standing `dist` meters from the core (the core is at (-7.5, 3.0)).
static func crowd(w: SimWorld, n: int, dist: float = 3.0, attacking: bool = false) -> void:
	for k: int in n:
		var i: int = w.spawn_enemy(Ids.EN_SKITTER, w.content.arena.core_x + dist, w.content.arena.core_z + 0.1 * float(k))
		if attacking and i >= 0:
			w.enemies.state[i] = EnemyStore.ST_ATTACKING


## The one command the bot queued; fails the test when there is not exactly one.
static func only(w: SimWorld) -> SimCommand:
	assert(w.command_queue.size() == 1, "expected exactly one queued command, got %d" % w.command_queue.size())
	return w.command_queue[0]


static func kinds(w: SimWorld) -> Array[int]:
	var out: Array[int] = []
	for c: SimCommand in w.command_queue:
		out.append(c.kind)
	return out
