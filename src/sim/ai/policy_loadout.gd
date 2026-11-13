class_name PolicyLoadout
extends RefCounted
## Weapons as the bots see them (VARIETY_SPEC 3, CONTENT 2 and 13): the two roles of a good loadout, the choice made
## over a crate, and when to swap. Pure functions of the world; the Warden carries `arsenal.slot_count` weapons.

enum Role { SINGLE, AREA }

## SALVAGE argument = choice * 16 + action: action 0..2 takes the weapon in that slot, 8 levels up, 9 scraps.
const LEVEL_UP_ACTION: int = 8
const SCRAP_ACTION: int = 9
const SCRAP_ARG: int = SCRAP_ACTION
const MAX_LEVEL: int = 3
## What a level-up is worth next to a tier point of the loadout score (a held weapon grows 25 % and then 55 %).
const LEVEL_UP_GAIN: float = 1.0
## Swap to the area weapon at this many enemies in reach, back at CALM_COUNT (CONTENT 13: 12 and 5). "In reach" is the
## radius of the area weapon itself around the Warden, never less than CROWD_RADIUS_M (the 10 m of CONTENT 13): a bot
## that counts only the enemies within 10 m of the core meets 12 of them in about 3 % of the combat ticks of the
## slice, so its second weapon stayed in the holster (V4-T finding), and an arc projector reaches 18 m.
const CROWD_COUNT: int = 12
const CALM_COUNT: int = 5
const CROWD_RADIUS_M: float = 10.0
## A weapon that vents or reloads for at least this many more ticks is "spent": the bot bridges with the other slot.
const BRIDGE_TICKS: int = 60
## A heat weapon above this fraction of its cap is not "ready" (it would vent after a shot or two).
const HEAT_READY_FRACTION: float = 0.5
## A bot that swapped waits this many ticks before it considers another swap (the swap itself takes about 24).
const SWAP_PAUSE_TICKS: int = 90
## Ticks between two looks at the crowd.
const SCAN_PERIOD: int = 6


## Area and chain weapons (cone, arc, shell, missiles) against single-target ones (hitscan, line, beam).
static func role_of(def: WeaponDef) -> int:
	match def.kind:
		WeaponDef.Kind.CONE, WeaponDef.Kind.ARC, WeaponDef.Kind.SHELL, WeaponDef.Kind.MISSILES:
			return Role.AREA
		_:
			return Role.SINGLE


static func slot_total(world: SimWorld) -> int:
	return clampi(world.arsenal.slot_count, 1, ArsenalState.MAX_SLOTS)


## Weapon index in `slot`, -1 when empty or out of range.
static func weapon_in(world: SimWorld, slot: int) -> int:
	if slot < 0 or slot >= slot_total(world):
		return -1
	var weapon_index: int = world.arsenal.slot_weapon[slot]
	return weapon_index if weapon_index < world.content.weapons.size() else -1


## Tier of the weapon in `slot`, 0 when empty.
static func tier_in(world: SimWorld, slot: int) -> int:
	var weapon_index: int = weapon_in(world, slot)
	return world.content.weapons[weapon_index].tier if weapon_index >= 0 else 0


## First slot that holds `weapon_index`, -1 when it is not carried.
static func carried_slot(world: SimWorld, weapon_index: int) -> int:
	for slot: int in slot_total(world):
		if weapon_in(world, slot) == weapon_index:
			return slot
	return -1


static func can_level_up(world: SimWorld, weapon_index: int) -> bool:
	var slot: int = carried_slot(world, weapon_index)
	return slot >= 0 and world.arsenal.slot_level[slot] < MAX_LEVEL


## The first empty slot; with none empty, the slot with the lowest tier (ties to the later slot, so slot 1 is
## replaced before slot 0).
static func emptiest_slot(world: SimWorld) -> int:
	var best: int = 0
	var best_tier: int = 1 << 20
	for slot: int in slot_total(world):
		if weapon_in(world, slot) < 0:
			return slot
		var tier: int = tier_in(world, slot)
		if tier <= best_tier:
			best = slot
			best_tier = tier
	return best


## `greedy`: the first weapon of the crate, levelled up when it is a duplicate, else into the emptiest slot.
static func greedy_salvage_arg(world: SimWorld) -> int:
	var offer: PackedInt32Array = world.salvage.offer
	if offer.is_empty():
		return SCRAP_ARG
	if can_level_up(world, offer[0]):
		return LEVEL_UP_ACTION
	return emptiest_slot(world)


## Every legal answer to the crate, as SALVAGE arguments in a fixed order (choice, then slots, level up, scrap).
static func legal_args(world: SimWorld) -> Array[int]:
	var out: Array[int] = []
	var offer: PackedInt32Array = world.salvage.offer
	for choice: int in offer.size():
		for slot: int in slot_total(world):
			out.append(choice * 16 + slot)
		if can_level_up(world, offer[choice]):
			out.append(choice * 16 + LEVEL_UP_ACTION)
	out.append(SCRAP_ARG)
	return out


## The loadout score: the best tier of each role plus a hundredth of every tier carried (so a filled slot beats an
## empty one). `slot` is replaced by `weapon_index` (-2 = nothing replaced).
static func loadout_score(world: SimWorld, slot: int, weapon_index: int) -> float:
	var best_area: int = 0
	var best_single: int = 0
	var carried_tiers: int = 0
	for s: int in slot_total(world):
		var w: int = weapon_index if s == slot else weapon_in(world, s)
		if w < 0:
			continue
		var def: WeaponDef = world.content.weapons[w]
		carried_tiers += def.tier
		if role_of(def) == Role.AREA:
			best_area = maxi(best_area, def.tier)
		else:
			best_single = maxi(best_single, def.tier)
	return float(best_area + best_single) + 0.01 * float(carried_tiers)


## `balanced`: the answer that raises the loadout score most (one area or chain weapon, one single-target weapon, best
## tiers), a level-up of a carried duplicate, else scrapping the crate for Scrap. Ties go to the lower choice, then
## the lower slot.
static func balanced_salvage_arg(world: SimWorld) -> int:
	var offer: PackedInt32Array = world.salvage.offer
	var best_arg: int = SCRAP_ARG
	var best_gain: float = 0.0
	var base: float = loadout_score(world, -2, -1)
	for choice: int in offer.size():
		var weapon_index: int = offer[choice]
		if weapon_index < 0 or weapon_index >= world.content.weapons.size():
			continue
		if carried_slot(world, weapon_index) >= 0:
			if can_level_up(world, weapon_index) and LEVEL_UP_GAIN > best_gain:
				best_gain = LEVEL_UP_GAIN
				best_arg = choice * 16 + LEVEL_UP_ACTION
			continue
		for slot: int in slot_total(world):
			var gain: float = loadout_score(world, slot, weapon_index) - base
			if gain > best_gain:
				best_gain = gain
				best_arg = choice * 16 + slot
	return best_arg


## The weapon in `slot` can fire now and keeps firing: not reloading, venting or swapping, and a heat weapon not near its
## cap (a magazine is refilled by its reload, so "ready" is the state the HUD shows as READY).
static func slot_ready(world: SimWorld, slot: int) -> bool:
	if weapon_in(world, slot) < 0 or ArsenalSystem.slot_state(world, slot) != ArsenalSystem.ST_READY:
		return false
	var cap: int = ArsenalSystem.heat_cap_of(world, slot)
	return cap == 0 or float(world.arsenal.slot_heat[slot]) <= HEAT_READY_FRACTION * float(cap)


## The weapon in `slot` is out of action for a while: venting or reloading with BRIDGE_TICKS or more to go.
static func slot_spent(world: SimWorld, slot: int) -> bool:
	var state: int = ArsenalSystem.slot_state(world, slot)
	if state != ArsenalSystem.ST_VENTING and state != ArsenalSystem.ST_RELOADING:
		return false
	return ArsenalSystem.slot_ticks_left(world, slot) >= BRIDGE_TICKS


## The radius the crowd is counted in: the reach of the best area weapon carried (never below CROWD_RADIUS_M).
static func crowd_radius(world: SimWorld) -> float:
	var slot: int = best_slot_of_role(world, Role.AREA, -1)
	if slot < 0:
		return CROWD_RADIUS_M
	return maxf(CROWD_RADIUS_M, ArsenalSystem.range_of(world, world.content.weapons[weapon_in(world, slot)]))


## Enemies the area weapon could be fired at: living enemies within `crowd_radius` of the Warden.
static func crowd_count(world: SimWorld) -> int:
	return PolicySenses.near_warden(world, crowd_radius(world))


## `balanced` swap rule: the slot to swap to, or -1. To the best area weapon at CROWD_COUNT enemies in reach while a
## single-target weapon is active (and the area weapon is ready), back to the best single-target weapon at CALM_COUNT,
## or at once when the area weapon is spent (it vents or reloads) and a single-target weapon can fire meanwhile.
static func swap_target(world: SimWorld, crowd: int) -> int:
	var active: int = world.arsenal.active
	var active_weapon: int = weapon_in(world, active)
	if active_weapon < 0:
		return -1
	var role: int = role_of(world.content.weapons[active_weapon])
	if crowd >= CROWD_COUNT and role == Role.SINGLE:
		var area: int = best_slot_of_role(world, Role.AREA, active)
		return area if area >= 0 and slot_ready(world, area) else -1
	if role == Role.AREA:
		var single: int = best_slot_of_role(world, Role.SINGLE, active)
		if single >= 0 and (crowd <= CALM_COUNT or (slot_spent(world, active) and slot_ready(world, single))):
			return single
	return -1


## The slot (other than `skip`) holding the highest-tier weapon of `role`, ties to the lower slot; -1 when none.
static func best_slot_of_role(world: SimWorld, role: int, skip: int) -> int:
	var best: int = -1
	var best_tier: int = 0
	for slot: int in slot_total(world):
		var weapon_index: int = weapon_in(world, slot)
		if slot == skip or weapon_index < 0:
			continue
		var def: WeaponDef = world.content.weapons[weapon_index]
		if role_of(def) == role and def.tier > best_tier:
			best = slot
			best_tier = def.tier
	return best


## Looks at the crowd every SCAN_PERIOD ticks and swaps by the rule above. One SWAP_WEAPON per SWAP_PAUSE_TICKS.
static func act_swap(world: SimWorld, bot: PolicyBot) -> void:
	if world.arsenal.swap_left > 0 or slot_total(world) < 2:
		return
	if world.tick % SCAN_PERIOD != 0 or world.tick < bot.swap_not_before:
		return
	send_swap(world, bot, swap_target(world, crowd_count(world)))


## One SWAP_WEAPON to `target` (ignored for -1 or the active slot) and the pause before the next one.
static func send_swap(world: SimWorld, bot: PolicyBot, target: int) -> void:
	if target >= 0 and target != world.arsenal.active:
		bot.send(world, SimCommand.Kind.SWAP_WEAPON, target)
		bot.swap_not_before = world.tick + SWAP_PAUSE_TICKS
