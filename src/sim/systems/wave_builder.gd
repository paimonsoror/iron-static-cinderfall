class_name WaveBuilder
extends RefCounted
## Turns a pack and a budget into spawn groups (VARIETY_SPEC 5.3, CONTENT 1.3): count = max(1, roundi(budget * share
## / cost * (0.9 + 0.2 * u))) with u from `stream`, interval = clamp(window * (1 - start) * tempo / count, 0.08, 4.0) s,
## a type below its min_act becomes skitter at the same budget. Then the composition rules of WaveRules (specialist cap,
## 40 percent fodder, the budget fit, reclaimer and burster timing). Used by RunPlanSystem only; draws only from the
## stream it is given, `plan.wave:<w>:<o>`, one draw per pack group in group order.

## Rule 6 of 5.3: nothing is scheduled in the first 4 seconds after the boss enters.
const BOSS_QUIET_TICKS: int = 240


## The groups of one route option. `stream` is `plan.wave:<w>:<o>`. `first_start_tick` keeps every group from starting
## earlier (the boss escorts use BOSS_QUIET_TICKS).
static func build(
	content: ContentSet,
	slot: WaveSlotDef,
	pack_index: int,
	budget_mult: float,
	stream: RandomNumberGenerator,
	first_start_tick: int = 0
) -> Array[SpawnGroupDef]:
	var pack: PackDef = content.run.packs[pack_index]
	var budget: float = slot.budget * pack.budget_mult * budget_mult
	var drafts: Array[GroupDraft] = []
	for g: int in pack.group_count():
		var enemy_index: int = pack.group_enemy[g]
		if content.enemies[enemy_index].min_act > slot.act:
			enemy_index = Ids.EN_SKITTER
		var d: GroupDraft = GroupDraft.new()
		d.enemy_index = enemy_index
		d.cost = _cost(content, enemy_index)
		d.count = formula_count(budget, pack.group_share[g], d.cost, PlanRng.unit(stream))
		d.start_frac = pack.group_start[g]
		d.tempo = pack.group_tempo[g]
		d.region = pack.group_region[g]
		d.min_start_tick = first_start_tick
		drafts.append(d)
	return _finish(content, slot, drafts, budget)


## The groups of a boss wave: the boss first (one body, tick 0), then its escorts from the wave budget, none before
## BOSS_QUIET_TICKS. `stream` is `plan.wave:<w>:0`. A boss with no escorts spawns alone.
static func boss_wave(
	content: ContentSet, slot: WaveSlotDef, boss_enemy_index: int, stream: RandomNumberGenerator
) -> Array[SpawnGroupDef]:
	var out: Array[SpawnGroupDef] = []
	var boss: GroupDraft = GroupDraft.new()
	boss.enemy_index = boss_enemy_index
	boss.cost = 0.0
	boss.count = 1
	boss.region = _region_id(content, 1)
	out.append(boss.to_def(slot.window_ticks))
	var def: BossDef = _boss_def(content, boss_enemy_index)
	if def == null:
		return out
	if def.escort_pack != &"" and content.run.pack_index(def.escort_pack) >= 0:
		var pack_index: int = content.run.pack_index(def.escort_pack)
		out.append_array(build(content, slot, pack_index, 1.0, stream, BOSS_QUIET_TICKS))
		return out
	var drafts: Array[GroupDraft] = []
	for k: int in def.escort_enemy.size():
		var d: GroupDraft = GroupDraft.new()
		d.enemy_index = def.escort_enemy[k]
		d.cost = _cost(content, d.enemy_index)
		d.count = formula_count(slot.budget, def.escort_share[k], d.cost, PlanRng.unit(stream))
		d.start_frac = clampf(float(BOSS_QUIET_TICKS) / float(maxi(1, slot.window_ticks)), 0.0, 0.9)
		d.region = _region_id(content, k)
		d.min_start_tick = BOSS_QUIET_TICKS
		drafts.append(d)
	out.append_array(_finish(content, slot, drafts, slot.budget))
	return out


## Applies the plan-level parts of a wave modifier to `groups` (CONTENT 1.4): `twin_gate` splits every right-edge group
## half and half onto the upper-right edge (each half spaced twice as wide, so the wave keeps its length), and the
## `spawn_interval_mul` stat scales every interval. Other ops are runtime effects of ModSystem and are ignored here.
static func apply_modifier(content: ContentSet, groups: Array[SpawnGroupDef], modifier_index: int) -> void:
	if modifier_index < 0 or modifier_index >= content.run.modifiers.size():
		return
	var ops: Array[OpDef] = content.run.modifiers[modifier_index].ops
	if has_flag(ops, &"twin_gate") and content.arena.region(&"upper_right") != null:
		_twin_gate(groups)
	var factor: float = stat(ops, &"spawn_interval_mul", 1.0)
	if not is_equal_approx(factor, 1.0):
		for g: SpawnGroupDef in groups:
			g.interval_ticks = maxi(1, roundi(float(g.interval_ticks) * factor))


## True when `ops` holds the flag `flag_name`.
static func has_flag(ops: Array[OpDef], flag_name: StringName) -> bool:
	for op: OpDef in ops:
		if op.kind == OpDef.Kind.FLAG and op.target == flag_name:
			return true
	return false


## The value of a stat after `ops` (ADD adds, MUL multiplies), starting from `base`.
static func stat(ops: Array[OpDef], stat_name: StringName, base: float) -> float:
	var v: float = base
	for op: OpDef in ops:
		if op.target != stat_name:
			continue
		if op.kind == OpDef.Kind.ADD:
			v += op.value
		elif op.kind == OpDef.Kind.MUL:
			v *= op.value
	return v


static func _finish(
	content: ContentSet, slot: WaveSlotDef, drafts: Array[GroupDraft], budget: float
) -> Array[SpawnGroupDef]:
	WaveRules.cap_specialists(content, drafts, slot.act)
	WaveRules.lift_fodder(content, drafts)
	WaveRules.fit_budget(drafts, budget)
	WaveRules.delay_reclaimers(drafts, slot.window_ticks)
	var out: Array[SpawnGroupDef] = []
	for d: GroupDraft in drafts:
		out.append(d.to_def(slot.window_ticks))
	WaveRules.delay_bursters(out)
	return out


## count = max(1, roundi(budget * share / cost * (0.9 + 0.2 * u))) (CONTENT 1.3).
static func formula_count(budget: float, share: float, cost: float, u: float) -> int:
	return maxi(1, roundi(budget * share / cost * (0.9 + 0.2 * u)))


static func _cost(content: ContentSet, enemy_index: int) -> float:
	var c: float = content.enemies[enemy_index].cost
	return c if c > 0.0 else 1.0


static func _boss_def(content: ContentSet, enemy_index: int) -> BossDef:
	for b: BossDef in content.bosses:
		if b.enemy_index == enemy_index:
			return b
	return null


## The id of spawn region `n` (wrapping), or &"right" when the arena has none.
static func _region_id(content: ContentSet, n: int) -> StringName:
	var regions: Array[SpawnRegionDef] = content.arena.spawn_regions
	if regions.is_empty():
		return &"right"
	return regions[n % regions.size()].id


static func _twin_gate(groups: Array[SpawnGroupDef]) -> void:
	var out: Array[SpawnGroupDef] = []
	for g: SpawnGroupDef in groups:
		out.append(g)
		if g.region_id != &"right" or g.count < 2:
			continue
		var other: SpawnGroupDef = SpawnGroupDef.new()
		other.enemy_index = g.enemy_index
		other.count = floori(float(g.count) / 2.0)
		other.start_tick = g.start_tick
		other.interval_ticks = mini(GroupDraft.MAX_INTERVAL_TICKS, g.interval_ticks * 2)
		other.region_id = &"upper_right"
		g.count -= other.count
		g.interval_ticks = mini(GroupDraft.MAX_INTERVAL_TICKS, g.interval_ticks * 2)
		out.append(other)
	groups.assign(out)
