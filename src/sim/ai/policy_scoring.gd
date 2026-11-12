class_name PolicyScoring
extends RefCounted
## The `balanced` bot's judgement of a draft and of a route (CONTENT 13). Pure functions of the world: no random
## stream, no memory. The numbers are the table of CONTENT 13; the reading of each clause is noted where it is not
## obvious.

## +3 when the directive shares a tag with at least TAG_HELD_MIN stacks the build already holds.
const TAG_BONUS: float = 3.0
const TAG_HELD_MIN: int = 2
## +2 when it fills a gap: no area source by wave 4, no armor answer by wave 6, no turret by wave 3, or a core
## directive while the core is below CORE_LOW. The gaps are judged for the wave that starts next.
const GAP_BONUS: float = 2.0
const AREA_BY_WAVE: int = 4
const ARMOR_BY_WAVE: int = 6
const TURRET_BY_WAVE: int = 3
const CORE_LOW: float = 0.6
## +1 per rarity step (common 0, rare 1, prototype 2, corrupted 3), -4 for a corrupted one while the core is below
## CORRUPT_CORE.
const RARITY_STEP: float = 1.0
const CORRUPT_PENALTY: float = 4.0
const CORRUPT_CORE: float = 0.5
## Reroll an offer whose best card scores below REROLL_BELOW, paying only with REROLL_SCRAP Scrap or more.
const REROLL_BELOW: float = 2.0
const REROLL_SCRAP: int = 150
const MAX_REROLLS_PER_DRAFT: int = 3
## Patch the core (a draft purchase) below PATCH_CORE while REROLL_SCRAP Scrap is left over after paying.
const PATCH_CORE: float = 0.6
const MAX_PATCHES_PER_DRAFT: int = 1
## Route: take the hot option while the core is at HOT_CORE or better and its reward is one of these.
const HOT_CORE: float = 0.7
const HOT_REWARDS: Array[StringName] = [&"rw_crate", &"rw_double_pick", &"rw_rare_draft"]
## Ties between equal scores go by category (weapons first), then to the leftmost slot.
const CATEGORY_RANK: Array[int] = [
	5,  # WEAPON
	4,  # TURRET
	3,  # CORE
	2,  # ABILITY
	1,  # ECONOMY
	0,  # CORRUPTED
]
const AREA_TAGS: Array[StringName] = [&"blast", &"arc"]
const NO_TAGS: Array[StringName] = []


## The score of one directive for the build and the core as they stand.
static func score(world: SimWorld, directive_index: int) -> float:
	var d: DirectiveDef = world.content.directives[directive_index]
	var total: float = RARITY_STEP * float(d.rarity)
	if shared_stacks(world, d) >= TAG_HELD_MIN:
		total += TAG_BONUS
	if fills_gap(world, d):
		total += GAP_BONUS
	if d.rarity == DirectiveDef.Rarity.CORRUPTED and PolicySenses.core_fraction(world) < CORRUPT_CORE:
		total -= CORRUPT_PENALTY
	return total


## Stacks held in directives that share at least one tag with `d` (the directive itself counts).
static func shared_stacks(world: SimWorld, d: DirectiveDef) -> int:
	var n: int = 0
	for held: DirectiveDef in world.content.directives:
		var stacks: int = world.draft.stacks_of(held.index)
		if stacks > 0 and shares_tag(held, d):
			n += stacks
	return n


static func shares_tag(a: DirectiveDef, b: DirectiveDef) -> bool:
	for tag: StringName in a.tags:
		if b.tags.has(tag):
			return true
	return false


## True when `d` closes a gap that is open for the wave that starts next.
static func fills_gap(world: SimWorld, d: DirectiveDef) -> bool:
	var ahead: int = PolicySenses.next_wave(world)
	if ahead >= AREA_BY_WAVE and not has_area_source(world) and has_any_tag(d, AREA_TAGS):
		return true
	if ahead >= ARMOR_BY_WAVE and not has_armor_answer(world) and has_op(d, &"lvl_armor_piercing"):
		return true
	if ahead >= TURRET_BY_WAVE and not has_turret(world) and has_op(d, &"turrets"):
		return true
	return d.category == DirectiveDef.Category.CORE and PolicySenses.core_fraction(world) < CORE_LOW


static func has_any_tag(d: DirectiveDef, tags: Array[StringName]) -> bool:
	for tag: StringName in tags:
		if d.tags.has(tag):
			return true
	return false


static func has_op(d: DirectiveDef, stat_name: StringName) -> bool:
	for op: OpDef in d.ops:
		if op.target == stat_name and op.value > 0.0:
			return true
	return false


## True when a held directive carries one of `tags`, or has an op on `stat_name` (empty = not asked).
static func holds(world: SimWorld, tags: Array[StringName], stat_name: StringName) -> bool:
	for held: DirectiveDef in world.content.directives:
		if world.draft.stacks_of(held.index) <= 0:
			continue
		if (not tags.is_empty() and has_any_tag(held, tags)) or (stat_name != &"" and has_op(held, stat_name)):
			return true
	return false


static func has_area_source(world: SimWorld) -> bool:
	for slot: int in PolicyLoadout.slot_total(world):
		var w: int = PolicyLoadout.weapon_in(world, slot)
		if w >= 0 and PolicyLoadout.role_of(world.content.weapons[w]) == PolicyLoadout.Role.AREA:
			return true
	return holds(world, AREA_TAGS, &"")


static func has_armor_answer(world: SimWorld) -> bool:
	for slot: int in PolicyLoadout.slot_total(world):
		var w: int = PolicyLoadout.weapon_in(world, slot)
		if w >= 0 and (world.content.weapons[w].armor_ignore > 0.0 or world.content.weapons[w].armor_shred > 0.0):
			return true
	return world.upgrade_levels[Ids.UP_ARMOR_PIERCING] > 0 or holds(world, NO_TAGS, &"lvl_armor_piercing")


static func has_turret(world: SimWorld) -> bool:
	return world.turrets.active_count() > 0 or world.mods.turrets > 0.0 or holds(world, NO_TAGS, &"turrets")


## The open slot with the best score; ties by category rank, then leftmost. -1 when the offer is empty.
static func best_slot(world: SimWorld) -> int:
	var best: int = -1
	var top_score: float = 0.0
	var best_rank: int = 0
	for slot: int in PolicyAnswers.open_slots(world):
		var index: int = world.draft.offer[slot]
		var s: float = score(world, index)
		var rank: int = CATEGORY_RANK[world.content.directives[index].category]
		if best < 0 or s > top_score or (is_equal_approx(s, top_score) and rank > best_rank):
			best = slot
			top_score = s
			best_rank = rank
	return best


## The score of the best open slot, or -1000 when the offer is empty.
static func best_score(world: SimWorld) -> float:
	var slot: int = best_slot(world)
	return score(world, world.draft.offer[slot]) if slot >= 0 else -1000.0


## `balanced`: the route to take. Hot while the core is healthy and the reward is a crate, a double pick or a rare
## draft; otherwise the first standard option; option A when nothing is standard.
static func route_choice(world: SimWorld) -> int:
	var options: Array[RouteOption] = PolicyAnswers.route_options(world)
	if options.size() <= 1:
		return 0
	if PolicySenses.core_fraction(world) >= HOT_CORE:
		for i: int in options.size():
			if options[i].hot and HOT_REWARDS.has(reward_id(world, options[i])):
				return i
	for i: int in options.size():
		if not options[i].hot:
			return i
	return 0


static func reward_id(world: SimWorld, option: RouteOption) -> StringName:
	if world.content.run == null:
		return &""
	var rewards: Array[RewardDef] = world.content.run.route_rewards
	if option.reward_index < 0 or option.reward_index >= rewards.size():
		return &""
	return rewards[option.reward_index].id
