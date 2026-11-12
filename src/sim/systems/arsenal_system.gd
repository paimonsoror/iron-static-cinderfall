class_name ArsenalSystem
extends RefCounted
## Weapon slots, swapping, magazines, heat and the dispatch on WeaponDef.kind to the fire files (VARIETY_SPEC 3).
## The only writer of ArsenalState (SalvageSystem changes slot contents through `give_weapon` and `level_up`).
## WeaponSystem.step delegates here on variety content; WardenState.weapon_index, magazine and reload_ticks_left
## mirror the active slot.
##
## Per tick (the order of the legacy WeaponSystem, so a magazine weapon keeps the cadence of ARCH 6.5 exactly):
## swap countdown; holstered slots (reload at holster_reload_mult, cool and vent at full speed); the active slot's
## reload or vent countdown (a reload or vent that ends lets the weapon fire on the same tick); cadence accumulator;
## lock and aim; fire while a shot is allowed; clamp the accumulator; cooling; mirror.
## Swap (3.1): the new slot is active at once and nothing fires for the next swap_ticks combat ticks. Outside combat
## a swap is instant.
## Heat (3.3): a shot adds heat_per_shot; reaching the cap starts a vent of vent_ticks, after which heat is 0. The
## active weapon cools on every tick on which it holds no target or a swap runs ("not firing"); between the shots of
## a burst it does not cool.
# TODO(V4-W): weapon level-3 perks, the LMG spin-up, the off-hand of twin_link and the other firing kinds.

## Slot states for the HUD (RunApi.weapon_slot "state").
const ST_READY: int = 0
const ST_RELOADING: int = 1
const ST_VENTING: int = 2
const ST_SWAPPING: int = 3
const ST_CHARGING: int = 4
const ST_EMPTY: int = 5

const MILLI_PER_SHOT: int = 60000  ## sps_milli is shots per second x 1000; 60 ticks x 1000
const COOL_UNIT: int = 60  ## slot_cool_acc units per unit of heat (cool_per_s is added per tick)
const RELOAD_UNIT: int = 1000  ## slot_reload_acc units per reload tick
const MAX_LEVEL: int = 3


## Slot 0 gets the starting weapon with a full magazine. Called once by SimWorld._init.
static func init_world(world: SimWorld) -> void:
	world.arsenal.slot_magazine[0] = magazine_size_of(world, 0)
	if world.content.run != null and not world.stats.weapons.has(world.arsenal.slot_weapon[0]):
		world.stats.weapons.append(world.arsenal.slot_weapon[0])


static func step(world: SimWorld) -> void:
	var a: ArsenalState = world.arsenal
	var w: WardenState = world.warden
	var swapping: bool = a.swap_left > 0
	if swapping:
		a.swap_left -= 1
	for s: int in a.slot_count:
		if s != a.active and a.slot_weapon[s] >= 0:
			_tick_holstered(world, a, s)
	var slot: int = a.active
	var def: WeaponDef = weapon_of(world, slot)
	_tick_active(world, a, slot, def)
	w.fire_acc_milli += sps_milli(world, def)
	var range_m: float = range_of(world, def)
	var lock: PackedInt32Array = Targeting.refresh_lock(
		world, w.target_id, w.lock_ticks_left, w.x, w.z, range_m, world.content.mission.lock_ticks
	)
	w.target_id = lock[0]
	w.lock_ticks_left = lock[1]
	_aim(world, w)
	if not swapping:
		while w.fire_acc_milli >= MILLI_PER_SHOT and w.target_id != 0 and _can_fire(a, slot, def):
			if not _fire(world, a, slot, def, range_m):
				break
	if w.fire_acc_milli > MILLI_PER_SHOT:
		w.fire_acc_milli = MILLI_PER_SHOT
	if def.is_heat() and a.slot_vent_left[slot] == 0 and (swapping or w.target_id == 0):
		_cool(a, slot, def)
	_mirror(world)


## SWAP_WEAPON: makes `slot` the active slot; nothing fires for swap_ticks. Returns a Reason.Id; pushes WEAPON_SWAPPED.
## INVALID_CHOICE for a slot the Warden does not have; WRONG_STATE for the active slot, an empty slot, a swap that is
## still running, the legacy content and a finished run.
static func swap(world: SimWorld, _command_id: int, slot: int) -> int:
	var a: ArsenalState = world.arsenal
	if world.content.run == null or world.is_over():
		return Reason.Id.WRONG_STATE
	if slot < 0 or slot >= a.slot_count:
		return Reason.Id.INVALID_CHOICE
	if slot == a.active or a.slot_weapon[slot] < 0 or a.swap_left > 0:
		return Reason.Id.WRONG_STATE
	a.active = slot
	a.swap_left = swap_ticks(world) if GameState.is_combat(world.phase) else 0
	a.charge_left = 0
	a.spin_ticks = 0
	a.beam_target = 0
	a.beam_hits = 0
	_mirror(world)
	world.events.push(SimEventKind.Id.WEAPON_SWAPPED, slot, a.slot_weapon[slot])
	return Reason.Id.OK


## Puts a weapon into a slot (salvage, kits) at level 1 with a full magazine and no heat. Pushes WEAPON_CHANGED when
## it is the active slot.
static func give_weapon(world: SimWorld, slot: int, weapon_index: int) -> void:
	var a: ArsenalState = world.arsenal
	if slot < 0 or slot >= a.slot_count or weapon_index < 0 or weapon_index >= world.content.weapons.size():
		return
	a.slot_weapon[slot] = weapon_index
	a.slot_level[slot] = 1
	a.slot_reload_left[slot] = 0
	a.slot_reload_acc[slot] = 0
	a.slot_heat[slot] = 0
	a.slot_cool_acc[slot] = 0
	a.slot_vent_left[slot] = 0
	a.slot_magazine[slot] = magazine_size_of(world, slot)
	if not world.stats.weapons.has(weapon_index):
		world.stats.weapons.append(weapon_index)
	if slot == a.active:
		_mirror(world)
		world.events.push(SimEventKind.Id.WEAPON_CHANGED, weapon_index)


## Raises the level of the weapon in `slot` by one (cap MAX_LEVEL).
static func level_up(world: SimWorld, slot: int) -> void:
	var a: ArsenalState = world.arsenal
	if slot < 0 or slot >= a.slot_count or a.slot_weapon[slot] < 0:
		return
	a.slot_level[slot] = mini(MAX_LEVEL, a.slot_level[slot] + 1)


## The weapon in `slot`; the pistol for an empty slot.
static func weapon_of(world: SimWorld, slot: int) -> WeaponDef:
	var a: ArsenalState = world.arsenal
	if slot < 0 or slot >= a.slot_weapon.size() or a.slot_weapon[slot] < 0:
		return world.content.weapons[0]
	return world.content.weapons[a.slot_weapon[slot]]


## The slot that carries `weapon_index`, or -1.
static func slot_of(world: SimWorld, weapon_index: int) -> int:
	var a: ArsenalState = world.arsenal
	for s: int in a.slot_count:
		if a.slot_weapon[s] == weapon_index:
			return s
	return -1


## ST_* of `slot`.
static func slot_state(world: SimWorld, slot: int) -> int:
	var a: ArsenalState = world.arsenal
	if slot < 0 or slot >= a.slot_count or a.slot_weapon[slot] < 0:
		return ST_EMPTY
	if slot == a.active and a.swap_left > 0:
		return ST_SWAPPING
	if slot == a.active and a.charge_left > 0:
		return ST_CHARGING
	if a.slot_vent_left[slot] > 0:
		return ST_VENTING
	if a.slot_reload_left[slot] > 0:
		return ST_RELOADING
	return ST_READY


## Ticks left of what `slot_state` names (swap, charge, vent or reload at the active speed), else 0.
static func slot_ticks_left(world: SimWorld, slot: int) -> int:
	var a: ArsenalState = world.arsenal
	match slot_state(world, slot):
		ST_SWAPPING:
			return a.swap_left
		ST_CHARGING:
			return a.charge_left
		ST_VENTING:
			return a.slot_vent_left[slot]
		ST_RELOADING:
			return a.slot_reload_left[slot]
	return 0


## Magazine size of the weapon in `slot` with ModState.w_mag_mul (0 for a heat weapon).
static func magazine_size_of(world: SimWorld, slot: int) -> int:
	var def: WeaponDef = weapon_of(world, slot)
	if def.is_heat():
		return 0
	return maxi(1, roundi(float(def.magazine) * world.mods.w_mag_mul))


## Heat capacity of the weapon in `slot` with ModState.w_heat_cap_mul (0 for a magazine weapon).
static func heat_cap_of(world: SimWorld, slot: int) -> int:
	var def: WeaponDef = weapon_of(world, slot)
	if not def.is_heat():
		return 0
	return maxi(1, roundi(float(def.heat_cap) * world.mods.w_heat_cap_mul))


static func reload_ticks_of(world: SimWorld, def: WeaponDef) -> int:
	return maxi(1, roundi(float(def.reload_ticks) * world.mods.w_reload_mul))


static func vent_ticks_of(world: SimWorld, def: WeaponDef) -> int:
	return maxi(1, roundi(float(def.vent_ticks) * world.mods.w_reload_mul))


static func swap_ticks(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null:
		return 0
	return maxi(0, run.swap_ticks + roundi(world.mods.swap_ticks_add))


static func range_of(world: SimWorld, def: WeaponDef) -> float:
	return def.range_m * world.mods.range_mul


## Shots per second x 1000 of `def` for this tick: the weapon's rate with the fire_rate level, the overdrive
## multiplier while it is active (Formulas.sps_milli) and ModState.w_rate_mul.
static func sps_milli(world: SimWorld, def: WeaponDef) -> int:
	var rate_up: UpgradeDef = world.content.upgrades[Ids.UP_FIRE_RATE]
	var mult_milli: int = 1000
	if world.abilities.is_active(Ids.AB_OVERDRIVE):
		mult_milli = world.content.abilities[Ids.AB_OVERDRIVE].fire_rate_mult_milli
	var sps: int = Formulas.sps_milli(def.sps_milli, world.upgrade_levels[Ids.UP_FIRE_RATE], rate_up.per_level, mult_milli)
	if world.mods.w_rate_mul != 1.0:
		sps = maxi(0, roundi(float(sps) * world.mods.w_rate_mul))
	return sps


static func _tick_active(world: SimWorld, a: ArsenalState, slot: int, def: WeaponDef) -> void:
	if def.is_heat():
		if a.slot_vent_left[slot] > 0:
			a.slot_vent_left[slot] -= 1
			if a.slot_vent_left[slot] == 0:
				a.slot_heat[slot] = 0
				a.slot_cool_acc[slot] = 0
		return
	if a.slot_reload_left[slot] > 0:
		a.slot_reload_left[slot] -= 1
		if a.slot_reload_left[slot] == 0:
			a.slot_magazine[slot] = magazine_size_of(world, slot)
			a.slot_reload_acc[slot] = 0
			world.events.push(SimEventKind.Id.RELOAD_FINISHED)
	elif a.slot_magazine[slot] <= 0:
		_start_reload(world, a, slot, def)


## A holstered weapon reloads at holster_reload_mult, cools and vents at full speed, and pushes no events.
static func _tick_holstered(world: SimWorld, a: ArsenalState, slot: int) -> void:
	var def: WeaponDef = weapon_of(world, slot)
	if def.is_heat():
		if a.slot_vent_left[slot] > 0:
			a.slot_vent_left[slot] -= 1
			if a.slot_vent_left[slot] == 0:
				a.slot_heat[slot] = 0
				a.slot_cool_acc[slot] = 0
		else:
			_cool(a, slot, def)
		return
	if a.slot_reload_left[slot] <= 0:
		return
	a.slot_reload_acc[slot] += roundi(world.content.run.holster_reload_mult * float(RELOAD_UNIT))
	while a.slot_reload_acc[slot] >= RELOAD_UNIT and a.slot_reload_left[slot] > 0:
		a.slot_reload_acc[slot] -= RELOAD_UNIT
		a.slot_reload_left[slot] -= 1
	if a.slot_reload_left[slot] == 0:
		a.slot_magazine[slot] = magazine_size_of(world, slot)
		a.slot_reload_acc[slot] = 0


static func _cool(a: ArsenalState, slot: int, def: WeaponDef) -> void:
	if a.slot_heat[slot] <= 0:
		a.slot_cool_acc[slot] = 0
		return
	a.slot_cool_acc[slot] += def.cool_per_s
	while a.slot_cool_acc[slot] >= COOL_UNIT and a.slot_heat[slot] > 0:
		a.slot_cool_acc[slot] -= COOL_UNIT
		a.slot_heat[slot] -= 1
	if a.slot_heat[slot] == 0:
		a.slot_cool_acc[slot] = 0


static func _can_fire(a: ArsenalState, slot: int, def: WeaponDef) -> bool:
	if def.is_heat():
		return a.slot_vent_left[slot] == 0
	return a.slot_reload_left[slot] == 0 and a.slot_magazine[slot] > 0


static func _start_reload(world: SimWorld, a: ArsenalState, slot: int, def: WeaponDef) -> void:
	a.slot_reload_left[slot] = reload_ticks_of(world, def)
	a.slot_reload_acc[slot] = 0
	world.events.push(SimEventKind.Id.RELOAD_STARTED, a.slot_reload_left[slot])


## One shot of the active slot at the current target. False when the firing kind let no shot go. Pays the shot
## (accumulator, round or heat), starts the reload or the vent, and re-picks at once when the shot killed the target.
static func _fire(world: SimWorld, a: ArsenalState, slot: int, def: WeaponDef, range_m: float) -> bool:
	var w: WardenState = world.warden
	var target_index: int = world.enemies.index_of(w.target_id)
	var fired: bool = false
	match def.kind:
		WeaponDef.Kind.HITSCAN:
			fired = FireHitscan.fire(world, slot, def, DamageSource.Id.WARDEN)
		WeaponDef.Kind.ARC:
			fired = FireArc.fire(world, slot, def, DamageSource.Id.WARDEN)
	if not fired:
		return false
	w.fire_acc_milli -= MILLI_PER_SHOT
	w.shots_fired += 1
	world.combat.shots_by_source[DamageSource.Id.WARDEN] += 1
	ShotHooks.on_warden_shot(world, slot, target_index)
	if def.is_heat():
		a.slot_cool_acc[slot] = 0
		a.slot_heat[slot] += def.heat_per_shot
		var cap: int = heat_cap_of(world, slot)
		if a.slot_heat[slot] >= cap:
			a.slot_heat[slot] = cap
			a.slot_vent_left[slot] = vent_ticks_of(world, def)
			world.events.push(SimEventKind.Id.WEAPON_VENTED, slot, a.slot_vent_left[slot])
	else:
		a.slot_magazine[slot] -= 1
		if a.slot_magazine[slot] <= 0:
			_start_reload(world, a, slot, def)
	if world.enemies.index_of(w.target_id) < 0:
		w.target_id = Targeting.pick(world, w.x, w.z, range_m)
		w.lock_ticks_left = world.content.mission.lock_ticks if w.target_id != 0 else 0
		_aim(world, w)
	return true


static func _aim(world: SimWorld, w: WardenState) -> void:
	var i: int = world.enemies.index_of(w.target_id)
	if i >= 0:
		w.aim_x = world.enemies.x[i]
		w.aim_z = world.enemies.z[i]


## WardenState mirrors the active slot (the HUD, the view and the legacy tests read it).
static func _mirror(world: SimWorld) -> void:
	var a: ArsenalState = world.arsenal
	var w: WardenState = world.warden
	w.weapon_index = maxi(0, a.slot_weapon[a.active])
	w.magazine = a.slot_magazine[a.active]
	w.reload_ticks_left = a.slot_reload_left[a.active]
