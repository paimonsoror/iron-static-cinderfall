class_name PolicyHoard
extends RefCounted
## The `hoarder`'s weapons (CONTENT 13): it keeps the highest tiers it can and plays the highest tier whenever that
## weapon is ready. Pure functions of the world; no stream. Tiers decide, never the role or the id of a weapon.

## A weapon of a higher tier is worth this many level points (a level-up is one point).
const TIER_WEIGHT: int = 100


## The SALVAGE argument: the answer that raises the sum of carried tiers most (an empty slot or a lower tier makes room;
## a duplicate is levelled up while it can be), else scrapping the crate. Ties go to the lower choice, then the lower slot.
static func salvage_arg(world: SimWorld) -> int:
	var offer: PackedInt32Array = world.salvage.offer
	var best_arg: int = PolicyLoadout.SCRAP_ARG
	var best_gain: int = 0
	for choice: int in offer.size():
		var weapon_index: int = offer[choice]
		if weapon_index < 0 or weapon_index >= world.content.weapons.size():
			continue
		if PolicyLoadout.carried_slot(world, weapon_index) >= 0:
			if PolicyLoadout.can_level_up(world, weapon_index) and 1 > best_gain:
				best_gain = 1
				best_arg = choice * 16 + PolicyLoadout.LEVEL_UP_ACTION
			continue
		var tier: int = world.content.weapons[weapon_index].tier
		for slot: int in PolicyLoadout.slot_total(world):
			var gain: int = (tier - PolicyLoadout.tier_in(world, slot)) * TIER_WEIGHT + 1 - _level_in(world, slot)
			if gain > best_gain:
				best_gain = gain
				best_arg = choice * 16 + slot
	return best_arg


## The slot of the weapon of the highest tier (ties: higher level, then the lower slot), -1 when none is carried.
static func top_slot(world: SimWorld) -> int:
	var best: int = -1
	var best_key: int = -1
	for slot: int in PolicyLoadout.slot_total(world):
		if PolicyLoadout.weapon_in(world, slot) < 0:
			continue
		var key: int = PolicyLoadout.tier_in(world, slot) * TIER_WEIGHT + _level_in(world, slot)
		if key > best_key:
			best = slot
			best_key = key
	return best


## The slot to swap to, or -1. The top slot as soon as it is ready; while it is spent (reloading or venting for a while)
## the best other slot that can fire.
static func swap_target(world: SimWorld) -> int:
	var top: int = top_slot(world)
	var active: int = world.arsenal.active
	if top < 0:
		return -1
	if active != top:
		return top if PolicyLoadout.slot_ready(world, top) else -1
	if not PolicyLoadout.slot_spent(world, top):
		return -1
	var fallback: int = -1
	var fallback_key: int = -1
	for slot: int in PolicyLoadout.slot_total(world):
		if slot == top or not PolicyLoadout.slot_ready(world, slot):
			continue
		var key: int = PolicyLoadout.tier_in(world, slot) * TIER_WEIGHT + _level_in(world, slot)
		if key > fallback_key:
			fallback = slot
			fallback_key = key
	return fallback


## Looks every SCAN_PERIOD ticks; one SWAP_WEAPON per SWAP_PAUSE_TICKS, never during a swap.
static func act_swap(world: SimWorld, bot: PolicyBot) -> void:
	if world.arsenal.swap_left > 0 or PolicyLoadout.slot_total(world) < 2:
		return
	if world.tick % PolicyLoadout.SCAN_PERIOD != 0 or world.tick < bot.swap_not_before:
		return
	PolicyLoadout.send_swap(world, bot, swap_target(world))


static func _level_in(world: SimWorld, slot: int) -> int:
	return world.arsenal.slot_level[slot] if PolicyLoadout.weapon_in(world, slot) >= 0 else 0
