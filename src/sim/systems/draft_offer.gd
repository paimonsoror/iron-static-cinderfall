class_name DraftOffer
extends RefCounted
## How one offer is rolled (VARIETY_SPEC 4.3, CONTENT 3.7). Reads the world and draws from the stream it is given;
## it writes nothing. The order of the steps fixes the draw sequence, so every offer and every reroll is a pure function
## of (seed, unlocked pool, held directives, carried weapons, act, earlier decisions):
##   1. candidates: unlocked, not maxed, requirement met, sorted by id
##   2. per slot: a pity override, else a rarity roll with the act weights (an empty rarity falls to the next lower, then
##      the next higher); the first-turret pity takes slot 1, the rare pity the first slot after it
##   3. inside the rarity: a weighted pick without replacement
##   4. with the chance of the act (never in waves 1 and 2) one corrupted directive replaces the last slot

const TURRET_PITY_ID: StringName = &"turret_deploy"
const TURRET_PITY_FROM_WAVE: int = 2  ## the draft after wave 2 is the first with the guarantee
const NO_CORRUPTED_UP_TO_WAVE: int = 2  ## no corrupted directive in the offers of waves 1 and 2
const BASE_WEIGHT: float = 10.0
const AFTER_BOSS_PROTOTYPE_MULT: float = 3.0  ## CONTENT 1.1: the draft after an act boss leans to prototypes
const TAG_LEAN_MIN_STACKS: int = 2


## The directive indices offered: at most offer_size (+ draft_slots) entries, no duplicate. `force_rare` is rw_rare_draft.
static func roll(world: SimWorld, rng: RandomNumberGenerator, force_rare: bool) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var run: RunDef = world.content.run
	if run == null:
		return out
	var act: ActDef = run.act(clampi(world.phase_state.act, 1, maxi(1, run.acts.size())))
	var pool: Array[int] = candidates(world)
	var tags: Dictionary[StringName, int] = DraftSystem.build_tags(world)
	var weights: Dictionary[int, float] = {}
	for index: int in pool:
		weights[index] = weight_of(world, world.content.directives[index], tags)
	var slots: int = run.draft_offer_size + roundi(world.mods.draft_slots)
	var rarity_w: PackedFloat32Array = rarity_weights(world, act)
	var turret: int = turret_pity_pick(world, pool)
	var rare_due: bool = force_rare or (run.rare_pity > 0 and world.draft.offers_without_rare >= run.rare_pity)
	var rare_slot: int = 1 if turret >= 0 else 0
	for slot: int in slots:
		var pick: int = -1
		if slot == 0 and turret >= 0:
			pick = turret
		elif rare_due and slot == rare_slot:
			var rare_w: PackedFloat32Array = PackedFloat32Array([0.0, rarity_w[1], rarity_w[2]])
			pick = _pick(world, rng, pool, weights, out, _roll_rarity(rng, rare_w), true)
		if pick < 0:
			pick = _pick(world, rng, pool, weights, out, _roll_rarity(rng, rarity_w), false)
		if pick < 0:
			break
		out.append(pick)
	_corrupted_slot(world, rng, act, pool, weights, out, slots)
	return out


## Directive indices that may be offered now, sorted by id.
static func candidates(world: SimWorld) -> Array[int]:
	var out: Array[int] = []
	for def: DirectiveDef in world.content.directives:
		if is_candidate(world, def):
			out.append(def.index)
	var directives: Array[DirectiveDef] = world.content.directives
	out.sort_custom(func(a: int, b: int) -> bool: return String(directives[a].id) < String(directives[b].id))
	return out


static func is_candidate(world: SimWorld, def: DirectiveDef) -> bool:
	if def.pool != &"base" and not world.config.has_unlock(String(def.pool)):
		return false
	return world.draft.stacks_of(def.index) < def.max_stacks and requirement_met(world, def)


## The `requires{}` of a directive against the build: deployed turrets, a free pad, carried weapons, a carried kind.
static func requirement_met(world: SimWorld, def: DirectiveDef) -> bool:
	for key: StringName in def.requires:
		var need: float = def.requires[key]
		match key:
			&"turrets":
				if float(world.turrets.active_count()) < need:
					return false
			&"free_pad":
				if need > 0.0 and not EconomySystem.has_free_pad(world):
					return false
			&"weapons":
				if float(carried_weapons(world).size()) < need:
					return false
			&"weapon_kind":
				if not _carries_kind(world, roundi(need)):
					return false
	return true


## Weapon indices in the slots of the Warden (an empty slot holds -1 and is not listed).
static func carried_weapons(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var a: ArsenalState = world.arsenal
	for slot: int in mini(a.slot_count, a.slot_weapon.size()):
		if a.slot_weapon[slot] >= 0:
			out.append(a.slot_weapon[slot])
	return out


## Weight inside a rarity: 10, x tag_lean when the build holds 2+ stacks sharing a tag, x weapon_lean for a directive
## that modifies a carried weapon kind, x repeat_penalty when it was offered and not picked in the previous draft.
static func weight_of(world: SimWorld, def: DirectiveDef, tags: Dictionary[StringName, int]) -> float:
	var run: RunDef = world.content.run
	var w: float = BASE_WEIGHT
	for tag: StringName in def.tags:
		var held: int = tags.get(tag, 0)
		if held >= TAG_LEAN_MIN_STACKS:
			w *= run.tag_lean
			break
	if def.requires.has(&"weapon_kind"):
		w *= run.weapon_lean
	if world.draft.last_offer.has(def.index):
		w *= run.repeat_penalty
	return w


## Common, rare, prototype weights of the act; the draft after a boss wave counts prototypes x3.
static func rarity_weights(world: SimWorld, act: ActDef) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
	for i: int in mini(3, act.rarity_weights.size()):
		out[i] = act.rarity_weights[i]
	if _after_boss(world):
		out[2] *= AFTER_BOSS_PROTOTYPE_MULT
	return out


## The index of turret_deploy when the first-turret pity applies, else -1.
static func turret_pity_pick(world: SimWorld, pool: Array[int]) -> int:
	if world.wave < TURRET_PITY_FROM_WAVE or world.draft.turret_offered or world.mods.has_flag(&"no_turret_pity"):
		return -1
	if world.turrets.active_count() > 0:
		return -1
	var index: int = world.content.directive_index(TURRET_PITY_ID)
	return index if index >= 0 and pool.has(index) else -1


static func _after_boss(world: SimWorld) -> bool:
	if world.plan == null:
		return false
	var planned: PlannedWave = world.plan.wave(world.wave)
	return planned != null and planned.is_boss


static func _carries_kind(world: SimWorld, kind: int) -> bool:
	for weapon_index: int in carried_weapons(world):
		if weapon_index < world.content.weapons.size() and world.content.weapons[weapon_index].kind == kind:
			return true
	return false


## One rarity index (0 common, 1 rare, 2 prototype) by weight; always one draw. All weights zero gives common.
static func _roll_rarity(rng: RandomNumberGenerator, weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var x: float = rng.randf() * total
	var acc: float = 0.0
	for r: int in weights.size():
		acc += weights[r]
		if x < acc:
			return r
	return DirectiveDef.Rarity.COMMON if total <= 0.0 else weights.size() - 1


## The rarities to try for `target`: itself, then each lower one, then each higher one. `rare_only` stops at rare.
static func _ladder(target: int, rare_only: bool) -> Array[int]:
	var out: Array[int] = []
	var lowest: int = DirectiveDef.Rarity.RARE if rare_only else DirectiveDef.Rarity.COMMON
	var r: int = target
	while r >= lowest:
		out.append(r)
		r -= 1
	for higher: int in range(target + 1, DirectiveDef.Rarity.PROTOTYPE + 1):
		out.append(higher)
	return out


## Step 3 for the slot: the weighted pick among the candidates of the first rarity of the ladder that has one.
static func _pick(
	world: SimWorld, rng: RandomNumberGenerator, pool: Array[int], weights: Dictionary[int, float],
	taken: PackedInt32Array, target: int, rare_only: bool
) -> int:
	for rarity: int in _ladder(target, rare_only):
		var cand: Array[int] = _of_rarity(world, pool, taken, rarity)
		if not cand.is_empty():
			return _weighted(rng, cand, weights)
	return -1


static func _of_rarity(world: SimWorld, pool: Array[int], taken: PackedInt32Array, rarity: int) -> Array[int]:
	var out: Array[int] = []
	for index: int in pool:
		if world.content.directives[index].rarity == rarity and not taken.has(index):
			out.append(index)
	return out


## One draw: the candidate whose cumulative weight passes x.
static func _weighted(rng: RandomNumberGenerator, cand: Array[int], weights: Dictionary[int, float]) -> int:
	var total: float = 0.0
	for index: int in cand:
		total += weights[index]
	var x: float = rng.randf() * total
	var acc: float = 0.0
	for index: int in cand:
		acc += weights[index]
		if x < acc:
			return index
	return cand[cand.size() - 1]


## Step 4: one chance roll (only when the act has a chance and the wave is past 2), then one extra pick.
static func _corrupted_slot(
	world: SimWorld, rng: RandomNumberGenerator, act: ActDef, pool: Array[int], weights: Dictionary[int, float],
	out: PackedInt32Array, slots: int
) -> void:
	if world.wave <= NO_CORRUPTED_UP_TO_WAVE or act.corrupted_chance <= 0.0:
		return
	if rng.randf() >= act.corrupted_chance:
		return
	var cand: Array[int] = _of_rarity(world, pool, out, DirectiveDef.Rarity.CORRUPTED)
	if cand.is_empty():
		return
	var pick: int = _weighted(rng, cand, weights)
	if not out.is_empty() and out.size() >= slots:
		out[out.size() - 1] = pick
	else:
		out.append(pick)
