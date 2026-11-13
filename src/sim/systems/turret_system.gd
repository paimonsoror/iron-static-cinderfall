class_name TurretSystem
extends RefCounted
## Auto turrets (ARCH 6.6; GDD 5.3). No magazine, no reload, damage level 0, own range and lock, unaffected
## by fire_rate and Overdrive (except through the directive flag `od_turrets`), but armor_piercing applies
## (DamageResolver). Pads are processed in index order; a hit's source is TURRET_0 + pad.
##
## Variety content (VARIETY_SPEC 7.4): while the turrets are offline (a brownout after a Core Surge, the Low Power
## modifier, a Tremor Rig stomp: EventState.turret_offline_ticks) nothing happens, not even the fire accumulator. The fire
## rate of a pad is EventRates.turret_rate_milli (Core Surge x2, ModState.t_rate_mul, od_turrets, a jammer aura), the damage
## is multiplied by ModState.t_dmg_mul. With the neutral values of the legacy content every number is the base one.

const MILLI_PER_SHOT: int = 60000


static func step(world: SimWorld) -> void:
	var def: UpgradeDef = world.content.upgrades[Ids.UP_AUTO_TURRET]
	var turrets: TurretStore = world.turrets
	if EventRates.turrets_offline(world):
		return
	for pad: int in turrets.active.size():
		if turrets.active[pad] == 1:
			_step_pad(world, def, pad)


static func _step_pad(world: SimWorld, def: UpgradeDef, pad: int) -> void:
	var t: TurretStore = world.turrets
	var rate: int = EventRates.turret_rate_milli(world, pad)
	if rate == EventRates.RATE_ONE:
		t.fire_acc_milli[pad] += def.turret_sps_milli
	else:
		t.fire_acc_milli[pad] += roundi(float(def.turret_sps_milli) * float(rate) / 1000.0)
	var lock: PackedInt32Array = Targeting.refresh_lock(
		world, t.target_id[pad], t.lock_ticks_left[pad], t.x[pad], t.z[pad], def.turret_range_m, def.turret_lock_ticks
	)
	t.target_id[pad] = lock[0]
	t.lock_ticks_left[pad] = lock[1]
	_aim(world, t, pad)
	while t.fire_acc_milli[pad] >= MILLI_PER_SHOT and t.target_id[pad] != 0:
		_fire(world, def, pad)
	if t.fire_acc_milli[pad] > MILLI_PER_SHOT:
		t.fire_acc_milli[pad] = MILLI_PER_SHOT


## One shot at the pad's target. Re-picks at once when the shot killed it.
static func _fire(world: SimWorld, def: UpgradeDef, pad: int) -> void:
	var t: TurretStore = world.turrets
	var source: int = DamageSource.Id.TURRET_0 + pad
	var target_id: int = t.target_id[pad]
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, target_id)
	t.fire_acc_milli[pad] -= MILLI_PER_SHOT
	world.combat.shots_by_source[source] += 1
	DamageResolver.hit(world, world.enemies.index_of(target_id), def.turret_damage * world.mods.t_dmg_mul, 0, source)
	if world.enemies.index_of(target_id) < 0:
		var picked: int = Targeting.pick(world, t.x[pad], t.z[pad], def.turret_range_m)
		t.target_id[pad] = picked
		t.lock_ticks_left[pad] = def.turret_lock_ticks if picked != 0 else 0
		_aim(world, t, pad)


static func _aim(world: SimWorld, t: TurretStore, pad: int) -> void:
	var i: int = world.enemies.index_of(t.target_id[pad])
	if i >= 0:
		t.aim_x[pad] = world.enemies.x[i]
		t.aim_z[pad] = world.enemies.z[i]
