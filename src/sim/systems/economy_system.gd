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


## Reason.Id.OK when the upgrade can be bought right now. Check order: state, id, max level, min_wave, funds.
static func block_reason(world: SimWorld, upgrade_index: int) -> int:
	if not _purchases_allowed(world.phase):
		return Reason.Id.WRONG_STATE
	if upgrade_index < 0 or upgrade_index >= world.content.upgrades.size() or upgrade_index >= world.upgrade_levels.size():
		return Reason.Id.UNKNOWN_ID
	var def: UpgradeDef = world.content.upgrades[upgrade_index]
	if world.upgrade_levels[upgrade_index] >= def.max_level:
		return Reason.Id.MAX_LEVEL
	if def.kind == UpgradeDef.Kind.TURRET and _free_pad(world) < 0:
		return Reason.Id.MAX_LEVEL
	# world.wave is 0 while PREPARING; that phase counts as "about to start wave 1", so a min_wave 1 upgrade is not
	# locked by it. Everything with min_wave >= 2 stays locked until that wave has started.
	if maxi(world.wave, 1) < def.min_wave:
		return Reason.Id.PREREQ_NOT_MET
	if world.scrap < world.upgrade_cost(upgrade_index):
		return Reason.Id.INSUFFICIENT_SCRAP
	return Reason.Id.OK


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
			world.warden.weapon_index = def.weapon_index
			world.warden.magazine = world.content.weapons[def.weapon_index].magazine
			world.warden.reload_ticks_left = 0
			world.events.push(SimEventKind.Id.WEAPON_CHANGED, def.weapon_index)
		_:
			pass
