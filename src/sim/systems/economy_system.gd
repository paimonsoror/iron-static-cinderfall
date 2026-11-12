class_name EconomySystem
extends RefCounted
## Upgrade purchases (ARCH 6.6 "Economy, abilities, flow"). A purchase is atomic: it either passes every check and
## then debits once, raises the level and applies its effect, or it changes nothing at all.


## Returns a Reason.Id; always pushes PURCHASE_RESOLVED (command id, reason, upgrade index).
static func purchase(world: SimWorld, command_id: int, upgrade_index: int) -> int:
	var reason: int = block_reason(world, upgrade_index)
	if reason == Reason.Id.OK:
		_apply(world, upgrade_index)
	world.events.push(SimEventKind.Id.PURCHASE_RESOLVED, command_id, reason, upgrade_index)
	return reason


## Reason.Id.OK when the upgrade can be bought right now. Check order: shop, state, id, max level, min_wave, funds.
## The shop is closed (SHOP_CLOSED) when `mission.shop_enabled` is false: the shipped variety mission buys directives
## on the draft screen instead. Only the legacy content keeps the shop.
static func block_reason(world: SimWorld, upgrade_index: int) -> int:
	if not world.content.mission.shop_enabled:
		return Reason.Id.SHOP_CLOSED
	if not _purchases_allowed(world.phase):
		return Reason.Id.WRONG_STATE
	if upgrade_index < 0 or upgrade_index >= world.content.upgrades.size() or upgrade_index >= world.upgrade_levels.size():
		return Reason.Id.UNKNOWN_ID
	var def: UpgradeDef = world.content.upgrades[upgrade_index]
	if world.upgrade_levels[upgrade_index] >= def.max_level:
		return Reason.Id.MAX_LEVEL
	if def.kind == UpgradeDef.Kind.TURRET and _free_pad(world) < 0:
		return Reason.Id.MAX_LEVEL
	if effective_wave(world) < def.min_wave:
		return Reason.Id.PREREQ_NOT_MET
	if world.scrap < world.upgrade_cost(upgrade_index):
		return Reason.Id.INSUFFICIENT_SCRAP
	return Reason.Id.OK


## The wave `min_wave` is compared with (GDD A1: the SMG is "purchasable from wave 2, first intermission onward").
## `world.wave` stays n through wave n's CLEARING and the INTERMISSION after it, so the rule is: PREPARING counts as
## wave 1 (world.wave is still 0), SPAWNING and CLEARING as the current wave, and INTERMISSION as the wave that is
## about to start (`world.wave + 1`).
static func effective_wave(world: SimWorld) -> int:
	if world.phase == GameState.Id.INTERMISSION:
		return world.wave + 1
	return maxi(world.wave, 1)


## -1 at max level. SimWorld.upgrade_cost already implements this; W1-C keeps the delegation.
static func cost(world: SimWorld, upgrade_index: int) -> int:
	return world.upgrade_cost(upgrade_index)


## Purchases are legal while a run is live and not over: PREPARING, SPAWNING, CLEARING, INTERMISSION.
static func _purchases_allowed(phase: int) -> bool:
	return (
		phase == GameState.Id.PREPARING
		or phase == GameState.Id.SPAWNING
		or phase == GameState.Id.CLEARING
		or phase == GameState.Id.INTERMISSION
	)


## Lowest inactive turret pad, or -1 when every pad is taken.
static func _free_pad(world: SimWorld) -> int:
	for pad: int in world.turrets.active.size():
		if world.turrets.active[pad] == 0:
			return pad
	return -1


## True when a turret can still be deployed: a pad is free and no effect has disabled the pads.
static func has_free_pad(world: SimWorld) -> bool:
	return not world.mods.has_flag(&"pads_disabled") and _free_pad(world) >= 0


## Variety runs (ModSystem.recompute): deploys turrets on the lowest free pads until `target` are active (never removes
## one) and mirrors the number of active pads into the legacy level `upgrade_levels[UP_AUTO_TURRET]`.
static func sync_turrets(world: SimWorld, target: int) -> void:
	var wanted: int = mini(target, world.turrets.active.size())
	while world.turrets.active_count() < wanted and has_free_pad(world):
		var pad: int = _free_pad(world)
		world.turrets.active[pad] = 1
		world.events.push(SimEventKind.Id.TURRET_DEPLOYED, pad)
	var count: int = world.turrets.active_count()
	if world.upgrade_levels[Ids.UP_AUTO_TURRET] != count:
		world.upgrade_levels[Ids.UP_AUTO_TURRET] = count
		world.events.push(SimEventKind.Id.UPGRADE_LEVEL_CHANGED, Ids.UP_AUTO_TURRET, count)


## Only called after block_reason returned OK: debit exactly once, raise the level, apply the effect.
static func _apply(world: SimWorld, upgrade_index: int) -> void:
	var def: UpgradeDef = world.content.upgrades[upgrade_index]
	world.add_scrap(-world.upgrade_cost(upgrade_index))
	var new_level: int = world.upgrade_levels[upgrade_index] + 1
	world.upgrade_levels[upgrade_index] = new_level
	world.events.push(SimEventKind.Id.UPGRADE_LEVEL_CHANGED, upgrade_index, new_level)
	match def.kind:
		UpgradeDef.Kind.TURRET:
			var pad: int = _free_pad(world)
			world.turrets.active[pad] = 1
			world.events.push(SimEventKind.Id.TURRET_DEPLOYED, pad)
		UpgradeDef.Kind.WEAPON_UNLOCK:
			if world.content.run != null:  # variety content: the arsenal owns the slots (the Warden mirrors them)
				ArsenalSystem.give_weapon(world, world.arsenal.active, def.weapon_index)
				return
			world.warden.weapon_index = def.weapon_index
			world.warden.magazine = world.content.weapons[def.weapon_index].magazine
			world.warden.reload_ticks_left = 0
			world.events.push(SimEventKind.Id.WEAPON_CHANGED, def.weapon_index)
		_:
			pass
