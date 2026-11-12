class_name WaveRules
extends RefCounted
## The composition rules of VARIETY_SPEC 5.3 as pure functions on the groups of one wave, plus the budget fit that keeps
## a wave within 5 percent of its budget. WaveBuilder calls them in this order: cap_specialists, lift_fodder, fit_budget,
## then (on the finished SpawnGroupDefs) delay_bursters. Nothing here draws a random number.

## Rule 2: types that count as specialists, and how many different ones one wave may hold (act I and II: 2, act III: 3).
const SPECIALISTS: PackedInt32Array = [Ids.EN_SPITTER, Ids.EN_RECLAIMER, Ids.EN_JAMMER, Ids.EN_SHIELDBEARER]
## Rule 3: basic fodder, and the share of the spent budget it must make up.
const FODDER: PackedInt32Array = [Ids.EN_SKITTER, Ids.EN_MOTE, Ids.EN_RUSHER]
const FODDER_MIN_FRAC: float = 0.4
## Rule 4: a reclaimer never spawns in the first fifth of the window.
const RECLAIMER_DELAY_FRAC: float = 0.2
## Rule 5: bursters never spawn as the first three bodies of a wave.
const BURSTER_AFTER_BODIES: int = 3
## The fit keeps the spent budget within this fraction of the target (the acceptance bound is 10 percent).
const BUDGET_TOLERANCE: float = 0.05


static func specialist_cap(act: int) -> int:
	return 3 if act >= 3 else 2


static func total(drafts: Array[GroupDraft]) -> float:
	var sum: float = 0.0
	for d: GroupDraft in drafts:
		sum += d.spent()
	return sum


static func fodder_total(drafts: Array[GroupDraft]) -> float:
	var sum: float = 0.0
	for d: GroupDraft in drafts:
		if FODDER.has(d.enemy_index):
			sum += d.spent()
	return sum


## Rule 2: from the cap-th different specialist type on, a group becomes skitters of the same spent budget.
static func cap_specialists(content: ContentSet, drafts: Array[GroupDraft], act: int) -> void:
	var cap: int = specialist_cap(act)
	var seen: PackedInt32Array = PackedInt32Array()
	var skitter_cost: float = skitter_cost_of(content)
	for d: GroupDraft in drafts:
		if not SPECIALISTS.has(d.enemy_index) or seen.has(d.enemy_index):
			continue
		if seen.size() < cap:
			seen.append(d.enemy_index)
			continue
		d.count = maxi(1, roundi(d.spent() / skitter_cost))
		d.enemy_index = Ids.EN_SKITTER
		d.cost = skitter_cost


## Rule 3: when fodder is below 40 percent of the spent budget, add exactly the fodder that lifts it to 40 percent.
static func lift_fodder(content: ContentSet, drafts: Array[GroupDraft]) -> void:
	var all: float = total(drafts)
	var fodder: float = fodder_total(drafts)
	if fodder >= FODDER_MIN_FRAC * all - 0.0001:
		return
	var needed: float = (FODDER_MIN_FRAC * all - fodder) / (1.0 - FODDER_MIN_FRAC)
	var unit: GroupDraft = cheapest_fodder(drafts)
	if unit == null:
		unit = GroupDraft.new()
		unit.enemy_index = Ids.EN_SKITTER
		unit.cost = skitter_cost_of(content)
		unit.count = 0
		unit.region = drafts[0].region if not drafts.is_empty() else &"right"
		drafts.append(unit)
	unit.count += maxi(1, ceili(needed / unit.cost))


## Moves the spent budget to within BUDGET_TOLERANCE of `target` by whole bodies of the cheapest fodder group (or the
## cheapest group when there is no fodder). Never drops a group below one body and never breaks rule 3.
static func fit_budget(drafts: Array[GroupDraft], target: float) -> void:
	var unit: GroupDraft = cheapest_fodder(drafts)
	if unit == null:
		unit = cheapest(drafts)
	if unit == null:
		return
	var band: float = target * BUDGET_TOLERANCE
	for _step: int in 400:
		var spent: float = total(drafts)
		if spent < target - band:
			if absf(spent + unit.cost - target) >= absf(spent - target):
				return
			unit.count += 1
		elif spent > target + band:
			if unit.count <= 1 or absf(spent - unit.cost - target) >= absf(spent - target):
				return
			unit.count -= 1
			if fodder_total(drafts) < FODDER_MIN_FRAC * total(drafts):
				unit.count += 1
				return
		else:
			return


## Rule 4: reclaimers start no earlier than a fifth of the window.
static func delay_reclaimers(drafts: Array[GroupDraft], window_ticks: int) -> void:
	for d: GroupDraft in drafts:
		if d.enemy_index == Ids.EN_RECLAIMER:
			d.min_start_tick = maxi(d.min_start_tick, ceili(RECLAIMER_DELAY_FRAC * float(window_ticks)))


## Rule 5: a burster group starts after the third body of the other groups has entered.
static func delay_bursters(groups: Array[SpawnGroupDef]) -> void:
	var ticks: PackedInt32Array = PackedInt32Array()
	for g: SpawnGroupDef in groups:
		if g.enemy_index == Ids.EN_BURSTER:
			continue
		for k: int in g.count:
			ticks.append(g.start_tick + k * g.interval_ticks)
	if ticks.is_empty():
		return
	ticks.sort()
	var third: int = ticks[mini(BURSTER_AFTER_BODIES, ticks.size()) - 1]
	for g: SpawnGroupDef in groups:
		if g.enemy_index == Ids.EN_BURSTER and g.start_tick <= third:
			g.start_tick = third + 1


static func skitter_cost_of(content: ContentSet) -> float:
	var c: float = content.enemies[Ids.EN_SKITTER].cost
	return c if c > 0.0 else 1.0


## The fodder group with the smallest cost (the first one on a tie), or null.
static func cheapest_fodder(drafts: Array[GroupDraft]) -> GroupDraft:
	var best: GroupDraft = null
	for d: GroupDraft in drafts:
		if FODDER.has(d.enemy_index) and (best == null or d.cost < best.cost):
			best = d
	return best


static func cheapest(drafts: Array[GroupDraft]) -> GroupDraft:
	var best: GroupDraft = null
	for d: GroupDraft in drafts:
		if best == null or d.cost < best.cost:
			best = d
	return best
