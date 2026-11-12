class_name PlanElites
extends RefCounted
## Which scheduled bodies of a route option are elites, and their affixes (VARIETY_SPEC 5.2, CONTENT 4.3). Rolled at tick
## 0 from the stream `plan.elite:<w>` (option A first, then option B) and stored as PlannedElite (group, ordinal, mask).

## Elites appear from wave 3 (VARIETY_SPEC 2.3); the opener, wave 2 and boss waves roll none.
const FIRST_ELITE_WAVE: int = 3
## Never elite: a burster (its blast would be unfair) and a boss part. Minis and bosses are excluded by their def.
const NEVER_ELITE: PackedInt32Array = [Ids.EN_BURSTER, Ids.EN_WARD_PYLON]
## A reclaimer is elite from this act on.
const RECLAIMER_ACT: int = 3
## Chance of the second affix when the data has no per-act value.
const DEFAULT_TWO_CHANCE: float = 0.5


## How many elites an option carries: the act's range on a normal wave from wave 3 on, +1 when the option is hot from
## act II, plus `extra` (the pack's `extra_elites` and the modifier's `extra_elites`). Always one draw.
static func count_for(content: ContentSet, slot: WaveSlotDef, hot: bool, extra: int, stream: RandomNumberGenerator) -> int:
	var act_def: ActDef = content.run.act(slot.act)
	var draw: int = PlanRng.index(stream, act_def.elites_max - act_def.elites_min + 1)
	if slot.kind != WaveSlotDef.Kind.NORMAL:
		return 0
	var n: int = extra
	if slot.index >= FIRST_ELITE_WAVE:
		n += act_def.elites_min + mini(draw, act_def.elites_max - act_def.elites_min)
	if hot and slot.act >= 2:
		n += 1
	return maxi(0, n)


## Fills `option.elites` (sorted by group, then ordinal) from the final groups of the option.
static func roll(
	content: ContentSet, slot: WaveSlotDef, option: RouteOption, extra: int, stream: RandomNumberGenerator
) -> void:
	option.elites.clear()
	var wanted: int = count_for(content, slot, option.hot, extra, stream)
	var cand_group: PackedInt32Array = PackedInt32Array()
	var cand_ordinal: PackedInt32Array = PackedInt32Array()
	for g: int in option.groups.size():
		if not eligible(content, option.groups[g].enemy_index, slot.act):
			continue
		for k: int in option.groups[g].count:
			cand_group.append(g)
			cand_ordinal.append(k)
	var n: int = mini(wanted, cand_group.size())
	for i: int in n:
		var j: int = i + PlanRng.index(stream, cand_group.size() - i)
		var swap_group: int = cand_group[i]
		var swap_ordinal: int = cand_ordinal[i]
		cand_group[i] = cand_group[j]
		cand_ordinal[i] = cand_ordinal[j]
		cand_group[j] = swap_group
		cand_ordinal[j] = swap_ordinal
	var picks: Array[PlannedElite] = []
	for i: int in n:
		var e: PlannedElite = PlannedElite.new()
		e.group = cand_group[i]
		e.ordinal = cand_ordinal[i]
		e.affix_mask = roll_affixes(content, option.groups[e.group].enemy_index, slot.act, stream)
		picks.append(e)
	for a: int in range(1, picks.size()):
		var moving: PlannedElite = picks[a]
		var b: int = a - 1
		while b >= 0 and _after(picks[b], moving):
			picks[b + 1] = picks[b]
			b -= 1
		picks[b + 1] = moving
	option.elites.append_array(picks)


## True when an enemy of this type may be an elite in `act`.
static func eligible(content: ContentSet, enemy_index: int, act: int) -> bool:
	var def: EnemyDef = content.enemies[enemy_index]
	if def.is_mini() or def.is_boss or NEVER_ELITE.has(enemy_index):
		return false
	return enemy_index != Ids.EN_RECLAIMER or act >= RECLAIMER_ACT


## The affix mask of one elite: the act's count (the second affix with the act's chance), drawn without replacement and
## never forming a forbidden pair for this enemy in this act. Always one draw for the count, one per affix.
static func roll_affixes(content: ContentSet, enemy_index: int, act: int, stream: RandomNumberGenerator) -> int:
	var run: RunDef = content.run
	var act_def: ActDef = run.act(act)
	var two: float = PlanRng.unit(stream)
	var wanted: int = act_def.affixes_min
	if act_def.affixes_max > act_def.affixes_min:
		var chance: float = run.affix_two_chance[act - 1] if act - 1 < run.affix_two_chance.size() else DEFAULT_TWO_CHANCE
		if two < chance:
			wanted = act_def.affixes_max
	var chosen: PackedInt32Array = PackedInt32Array()
	for _n: int in wanted:
		var usable: PackedInt32Array = PackedInt32Array()
		for a: AffixDef in content.affixes:
			if not chosen.has(a.index) and not _clashes(run, chosen, a.index, act, enemy_index):
				usable.append(a.index)
		if usable.is_empty():
			break
		chosen.append(usable[PlanRng.index(stream, usable.size())])
	var mask: int = 0
	for a: int in chosen:
		mask |= 1 << a
	return mask


## True when affix `candidate` forms a forbidden pair with one already `chosen` (CONTENT 4.3): `until_act` > 0 lifts the
## ban from that act on, a `forbid_enemy` >= 0 restricts it to that enemy type.
static func _clashes(run: RunDef, chosen: PackedInt32Array, candidate: int, act: int, enemy_index: int) -> bool:
	for k: int in run.forbid_a.size():
		var a: int = run.forbid_a[k]
		var b: int = run.forbid_b[k]
		var pair: bool = (a == candidate and chosen.has(b)) or (b == candidate and chosen.has(a))
		if not pair:
			continue
		if run.forbid_until_act[k] > 0 and act >= run.forbid_until_act[k]:
			continue
		if run.forbid_enemy[k] >= 0 and run.forbid_enemy[k] != enemy_index:
			continue
		return true
	return false


static func _after(a: PlannedElite, b: PlannedElite) -> bool:
	if a.group != b.group:
		return a.group > b.group
	return a.ordinal > b.ordinal
