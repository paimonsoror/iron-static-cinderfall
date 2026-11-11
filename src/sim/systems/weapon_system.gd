class_name WeaponSystem
extends RefCounted
## Warden targeting, fire cadence, magazine and reload (ARCH 6.5, 6.6; GDD 5.1).
##
## Per tick, in this order: reload countdown (a finished reload refills the magazine and the Warden may
## fire the same tick), cadence accumulator += sps_milli, lock/target refresh, fire while a shot is
## allowed, then clamp the accumulator to one shot so a pause never banks a burst.

const MILLI_PER_SHOT: int = 60000  ## sps_milli is shots per second x 1000; 60 ticks x 1000


static func step(world: SimWorld) -> void:
	var w: WardenState = world.warden
	var def: WeaponDef = world.content.weapons[w.weapon_index]
	_advance_reload(world, w, def)
	w.fire_acc_milli += current_sps_milli(world)
	var lock: PackedInt32Array = Targeting.refresh_lock(
		world, w.target_id, w.lock_ticks_left, w.x, w.z, def.range_m, world.content.mission.lock_ticks
	)
	w.target_id = lock[0]
	w.lock_ticks_left = lock[1]
	_aim(world, w)
	while w.fire_acc_milli >= MILLI_PER_SHOT and w.target_id != 0 and w.reload_ticks_left == 0 and w.magazine > 0:
		_fire(world, w, def)
	if w.fire_acc_milli > MILLI_PER_SHOT:
		w.fire_acc_milli = MILLI_PER_SHOT


## Warden shots per second x 1000 for this tick: the weapon's rate with the fire_rate level and, while
## overdrive is active, the overdrive multiplier (Formulas.sps_milli).
static func current_sps_milli(world: SimWorld) -> int:
	var def: WeaponDef = world.content.weapons[world.warden.weapon_index]
	var rate_up: UpgradeDef = world.content.upgrades[Ids.UP_FIRE_RATE]
	var mult_milli: int = 1000
	if world.abilities.is_active(Ids.AB_OVERDRIVE):
		mult_milli = world.content.abilities[Ids.AB_OVERDRIVE].fire_rate_mult_milli
	return Formulas.sps_milli(def.sps_milli, world.upgrade_levels[Ids.UP_FIRE_RATE], rate_up.per_level, mult_milli)


static func _advance_reload(world: SimWorld, w: WardenState, def: WeaponDef) -> void:
	if w.reload_ticks_left > 0:
		w.reload_ticks_left -= 1
		if w.reload_ticks_left == 0:
			w.magazine = def.magazine
			world.events.push(SimEventKind.Id.RELOAD_FINISHED)
	elif w.magazine <= 0:
		_start_reload(world, w, def)


static func _start_reload(world: SimWorld, w: WardenState, def: WeaponDef) -> void:
	w.reload_ticks_left = def.reload_ticks
	world.events.push(SimEventKind.Id.RELOAD_STARTED, def.reload_ticks)


## One shot at the current target. Re-picks at once when the shot killed it.
static func _fire(world: SimWorld, w: WardenState, def: WeaponDef) -> void:
	var target_index: int = world.enemies.index_of(w.target_id)
	world.events.push(SimEventKind.Id.SHOT_FIRED, DamageSource.Id.WARDEN, w.target_id)
	w.fire_acc_milli -= MILLI_PER_SHOT
	w.magazine -= 1
	w.shots_fired += 1
	world.combat.shots_by_source[DamageSource.Id.WARDEN] += 1
	DamageResolver.hit(world, target_index, def.damage, world.upgrade_levels[Ids.UP_DAMAGE], DamageSource.Id.WARDEN)
	if w.magazine <= 0:
		_start_reload(world, w, def)
	if world.enemies.index_of(w.target_id) < 0:
		w.target_id = Targeting.pick(world, w.x, w.z, def.range_m)
		w.lock_ticks_left = world.content.mission.lock_ticks if w.target_id != 0 else 0
		_aim(world, w)


static func _aim(world: SimWorld, w: WardenState) -> void:
	var i: int = world.enemies.index_of(w.target_id)
	if i >= 0:
		w.aim_x = world.enemies.x[i]
		w.aim_z = world.enemies.z[i]
