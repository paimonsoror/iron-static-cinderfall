class_name RunPlanSystem
extends RefCounted
## Builds the run plan at tick 0 (VARIETY_SPEC 9.3): bosses from `plan.boss`, both options of every normal wave from
## `plan.route:<w>` (pack, modifier, reward, hot flags) and `plan.wave:<w>:<o>` (the groups), elites from
## `plan.elite:<w>`, events from `plan.event:<w>`, fuel drum points from `plan.hazard:<act>`. Called once by
## SimWorld._init. The streams are PlanRng streams (same seeds as SimRng), so building draws nothing from `world.rng`.
##
## The whole plan is a function of the content and the run seed: a choice at wave 3 cannot change what wave 7 offers.
## Per option: A is standard (budget x1.0, a 25 percent chance of a mild modifier), B is hot (budget x1.25, always a
## modifier, one more elite from act II); from act II 15 percent of normal waves are "both hot" (CONTENT 1.2).

## CONTENT 1.2: the budget of a hot option, the chance of a mild modifier on a standard one, the both-hot chance.
const HOT_BUDGET_MULT: float = 1.25
const MILD_MODIFIER_CHANCE: float = 0.25
const BOTH_HOT_CHANCE: float = 0.15
const BOTH_HOT_FROM_ACT: int = 2
## CONTENT 6: 3 fuel drums per act, placed on 3 of the arena's drum points.
const DRUMS_PER_ACT: int = 3


## Null for the legacy content (no plan: SpawnSystem reads content.waves).
static func build(world: SimWorld) -> RunPlan:
	if not world.content.is_variety():
		return null
	var plan: RunPlan = build_for(world.content, world.config.run_seed)
	world.plan = plan
	for def: DirectiveDef in world.content.directives:  # a kit that gave a plan-patch directive at tick 0
		if def.hook == ModSystem.HOOK_PLAN_PATCH and world.draft.stacks_of(def.index) > 0:
			PlanPatch.apply(world, def.index)
	return plan


## The plan of `run_seed` on variety content. Pure: the same inputs always give the same plan.
static func build_for(content: ContentSet, run_seed: int) -> RunPlan:
	var plan: RunPlan = RunPlan.new()
	_bosses(plan, content, run_seed)
	var previous: PackedInt32Array = PackedInt32Array()
	for slot: WaveSlotDef in content.run.waves:
		var pw: PlannedWave = PlannedWave.new()
		pw.index = slot.index
		pw.act = slot.act
		pw.is_boss = slot.kind == WaveSlotDef.Kind.BOSS
		match slot.kind:
			WaveSlotDef.Kind.OPENER:
				pw.options.append(_fixed_option(content, slot, run_seed))
			WaveSlotDef.Kind.BOSS:
				pw.options.append(_boss_option(content, slot, plan, run_seed))
			_:
				_route_options(content, slot, run_seed, pw)
		var elite_stream: RandomNumberGenerator = PlanRng.stream(run_seed, StringName("plan.elite:%d" % slot.index))
		for o: RouteOption in pw.options:
			PlanElites.roll(content, slot, o, _extra_elites(content, o), elite_stream)
		var event_stream: RandomNumberGenerator = PlanRng.stream(run_seed, StringName("plan.event:%d" % slot.index))
		pw.events = PlanEvents.roll(content, slot, previous, event_stream)
		previous = PlanEvents.indices(pw.events)
		plan.waves.append(pw)
		plan.chosen.append(0)
	_drums(plan, content, run_seed)
	return plan


## Patches the remaining waves for a directive that changes the future (chorus_handshake, static_pact, open_gate),
## with the stream `plan.patch:<directive>:<w>` (see PlanPatch). DraftSystem calls it after the pick.
static func patch(world: SimWorld, directive_index: int) -> void:
	PlanPatch.apply(world, directive_index)


## Debug (DebugStart, `--scenario=boss:<id>`): makes `boss_enemy_index` the boss of the act of the boss wave `slot` and
## rebuilds the groups of that wave with the usual stream. Never called in a normal run.
static func set_boss(world: SimWorld, slot: WaveSlotDef, boss_enemy_index: int) -> void:
	var plan: RunPlan = world.plan
	var pw: PlannedWave = plan.wave(slot.index) if plan != null else null
	if pw == null or slot.act < 1 or slot.act > plan.boss_ids.size():
		return
	plan.boss_ids[slot.act - 1] = boss_enemy_index
	pw.options.clear()
	pw.options.append(_boss_option(world.content, slot, plan, world.config.run_seed))


## The boss of every act (an enemy index, -1 when the act has no boss pool) from `plan.boss`, then the Node 9 variant.
static func _bosses(plan: RunPlan, content: ContentSet, run_seed: int) -> void:
	var stream: RandomNumberGenerator = PlanRng.stream(run_seed, &"plan.boss")
	for act: int in range(1, content.run.acts.size() + 1):
		var pool: PackedInt32Array = PackedInt32Array()
		for b: BossDef in content.bosses:
			if b.pool_act == act:
				pool.append(b.enemy_index)
		var pick: int = PlanRng.index(stream, pool.size())
		plan.boss_ids.append(pool[pick] if not pool.is_empty() else -1)
	plan.boss_variant = PlanRng.index(stream, content.run.hulk_variants.size())


static func _fixed_option(content: ContentSet, slot: WaveSlotDef, run_seed: int) -> RouteOption:
	var o: RouteOption = RouteOption.new()
	o.pack_index = slot.fixed_pack_index
	var stream: RandomNumberGenerator = PlanRng.stream(run_seed, StringName("plan.wave:%d:0" % slot.index))
	o.groups = WaveBuilder.build(content, slot, o.pack_index, 1.0, stream)
	return o


static func _boss_option(content: ContentSet, slot: WaveSlotDef, plan: RunPlan, run_seed: int) -> RouteOption:
	var o: RouteOption = RouteOption.new()
	var boss_index: int = plan.boss_ids[slot.act - 1] if slot.act - 1 < plan.boss_ids.size() else -1
	if boss_index >= 0:
		var stream: RandomNumberGenerator = PlanRng.stream(run_seed, StringName("plan.wave:%d:0" % slot.index))
		o.groups = WaveBuilder.boss_wave(content, slot, boss_index, stream)
	return o


## Both options of a normal wave. `plan.route:<w>` draws, in this order: the both-hot roll; then for A and B in turn the
## pack, the modifier roll and pick, and the reward. Then each option's groups come from `plan.wave:<w>:<o>`.
static func _route_options(content: ContentSet, slot: WaveSlotDef, run_seed: int, pw: PlannedWave) -> void:
	var run: RunDef = content.run
	var stream: RandomNumberGenerator = PlanRng.stream(run_seed, StringName("plan.route:%d" % slot.index))
	var both_hot: bool = PlanRng.chance(stream, BOTH_HOT_CHANCE) and slot.act >= BOTH_HOT_FROM_ACT
	var packs: PackedInt32Array = _available_packs(run, slot.act)
	var a: RouteOption = RouteOption.new()
	a.hot = both_hot
	a.pack_index = _pick_pack(stream, packs, -1)
	a.modifier_index = _pick_modifier(run, stream, a.hot)
	a.reward_index = PlanRng.weighted(stream, _reward_weights(run, a.hot))
	var b: RouteOption = RouteOption.new()
	b.hot = true
	b.pack_index = _pick_pack(stream, packs, a.pack_index)
	b.modifier_index = _pick_modifier(run, stream, true)
	b.reward_index = PlanRng.weighted(stream, _reward_weights(run, true))
	var both: Array[RouteOption] = [a, b]
	for n: int in both.size():
		var o: RouteOption = both[n]
		var wave_stream: RandomNumberGenerator = PlanRng.stream(run_seed, StringName("plan.wave:%d:%d" % [slot.index, n]))
		o.groups = WaveBuilder.build(content, slot, o.pack_index, HOT_BUDGET_MULT if o.hot else 1.0, wave_stream)
		WaveBuilder.apply_modifier(content, o.groups, o.modifier_index)
		pw.options.append(o)


## Pack indices usable in `act` (min_act <= act), in file order; every pack when none qualifies.
static func _available_packs(run: RunDef, act: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for p: PackDef in run.packs:
		if p.min_act <= act:
			out.append(p.index)
	if out.is_empty():
		for p: PackDef in run.packs:
			out.append(p.index)
	return out


## One draw. The two options of a wave never share a pack unless only one is available.
static func _pick_pack(stream: RandomNumberGenerator, packs: PackedInt32Array, exclude: int) -> int:
	var usable: PackedInt32Array = PackedInt32Array()
	for p: int in packs:
		if p != exclude:
			usable.append(p)
	if usable.is_empty():
		usable = packs
	return usable[PlanRng.index(stream, usable.size())]


## Two draws (the chance roll and the pick). A hot option always gets a modifier (from the hot list, else the mild one);
## a standard option gets a mild one with MILD_MODIFIER_CHANCE. -1 = none.
static func _pick_modifier(run: RunDef, stream: RandomNumberGenerator, hot: bool) -> int:
	var mild: PackedInt32Array = PackedInt32Array()
	var heat: PackedInt32Array = PackedInt32Array()
	for m: ModifierDef in run.modifiers:
		if m.list == ModifierDef.List.HOT:
			heat.append(m.index)
		else:
			mild.append(m.index)
	var roll_chance: float = PlanRng.unit(stream)
	var roll_pick: int = PlanRng.index(stream, 1000)
	var pool: PackedInt32Array = mild
	if hot:
		pool = heat if not heat.is_empty() else mild
	elif roll_chance >= MILD_MODIFIER_CHANCE:
		return -1
	if pool.is_empty():
		return -1
	return pool[roll_pick % pool.size()]


static func _reward_weights(run: RunDef, hot: bool) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for r: RewardDef in run.route_rewards:
		out.append(r.weight_hot if hot else r.weight_standard)
	return out


## Elites an option brings beyond the act's range: the pack's `extra_elites` and the modifier's `extra_elites` stat.
static func _extra_elites(content: ContentSet, o: RouteOption) -> int:
	var extra: int = 0
	if o.pack_index >= 0:
		extra += content.run.packs[o.pack_index].extra_elites
	if o.modifier_index >= 0:
		extra += roundi(WaveBuilder.stat(content.run.modifiers[o.modifier_index].ops, &"extra_elites", 0.0))
	return extra


## 3 distinct drum points per act from `plan.hazard:<act>`, ascending, padded with -1 when the arena has fewer.
static func _drums(plan: RunPlan, content: ContentSet, run_seed: int) -> void:
	var points: int = content.arena.drum_points.size()
	for act: int in range(1, content.run.acts.size() + 1):
		var stream: RandomNumberGenerator = PlanRng.stream(run_seed, StringName("plan.hazard:%d" % act))
		var pool: PackedInt32Array = PackedInt32Array()
		for p: int in points:
			pool.append(p)
		var picks: PackedInt32Array = PackedInt32Array()
		for i: int in mini(DRUMS_PER_ACT, points):
			var j: int = i + PlanRng.index(stream, points - i)
			var held: int = pool[i]
			pool[i] = pool[j]
			pool[j] = held
			picks.append(pool[i])
		picks.sort()
		while picks.size() < DRUMS_PER_ACT:
			picks.append(-1)
		plan.drum_points.append_array(picks)
