class_name BuildSignature
extends RefCounted
## The build signature of a run (VARIETY_SPEC 14.2 S11): the primary weapon (most damage dealt) plus the two tags with
## the most stacks, e.g. "arc_projector+arc+tempo". Used by the scorecard and printed by tools/sim_run.
## The tags come from the directives held; a build with fewer than two tags has a shorter signature ("pistol",
## "smg+bullet"). Ties between tags go to the name that sorts first.

## Tags that count in the signature.
const TAG_COUNT: int = 2


## `tally` (WeaponDamageTally, fed by the harness) names the weapon that dealt the most damage. Without one the
## primary weapon is the best carried: highest tier, then level, then the active slot, then the lower index.
static func of(world: SimWorld, tally: WeaponDamageTally = null) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(String(world.content.weapons[primary_weapon(world, tally)].id))
	parts.append_array(top_tags(world))
	return "+".join(parts)


## Index of the primary weapon in ContentSet.weapons.
static func primary_weapon(world: SimWorld, tally: WeaponDamageTally = null) -> int:
	if tally != null:
		var dealt: int = tally.primary()
		if dealt >= 0 and dealt < world.content.weapons.size():
			return dealt
	var best: int = clampi(world.warden.weapon_index, 0, world.content.weapons.size() - 1)
	var best_key: float = _rank(world, best, 1, false)
	for slot: int in PolicyLoadout.slot_total(world):
		var weapon_index: int = PolicyLoadout.weapon_in(world, slot)
		if weapon_index < 0:
			continue
		var key: float = _rank(world, weapon_index, world.arsenal.slot_level[slot], slot == world.arsenal.active)
		if key > best_key or (is_equal_approx(key, best_key) and weapon_index < best):
			best = weapon_index
			best_key = key
	return best


## The `TAG_COUNT` tags with the most stacks held, most first.
static func top_tags(world: SimWorld) -> PackedStringArray:
	var totals: Dictionary[StringName, int] = {}
	for d: DirectiveDef in world.content.directives:
		var stacks: int = PolicySenses.stacks_of(world, d)  # never the raw count: hook directives keep counters in it
		if stacks <= 0:
			continue
		for tag: StringName in d.tags:
			var before: int = totals.get(tag, 0)
			totals[tag] = before + stacks
	var out: PackedStringArray = PackedStringArray()
	for _n: int in TAG_COUNT:
		var best: StringName = &""
		var best_total: int = 0
		for tag: StringName in totals:
			if out.has(String(tag)):
				continue
			if totals[tag] > best_total or (totals[tag] == best_total and best != &"" and String(tag) < String(best)):
				best = tag
				best_total = totals[tag]
		if best == &"":
			break
		out.append(String(best))
	return out


## Orders carried weapons: tier first, then level, then "in hand".
static func _rank(world: SimWorld, weapon_index: int, level: int, in_hand: bool) -> float:
	return float(world.content.weapons[weapon_index].tier) * 100.0 + float(level) * 10.0 + (1.0 if in_hand else 0.0)
