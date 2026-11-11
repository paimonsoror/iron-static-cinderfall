class_name TurretSystem
extends RefCounted
## Auto turrets (ARCH 6.6; GDD 5.3). No magazine, no reload, damage level 0, own range and lock, unaffected
## by fire_rate and Overdrive, but armor_piercing applies (DamageResolver). Pads are processed in index
## order; a hit's source is TURRET_0 + pad.

const MILLI_PER_SHOT: int = 60000


static func step(world: SimWorld) -> void:
	var def: UpgradeDef = world.content.upgrades[Ids.UP_AUTO_TURRET]
	var turrets: TurretStore = world.turrets
	for pad: int in turrets.active.size():
		if turrets.active[pad] == 1:
			_step_pad(world, def, pad)


static func _step_pad(world: SimWorld, def: UpgradeDef, pad: int) -> void:
	var t: TurretStore = world.turrets
	t.fire_acc_milli[pad] += def.turret_sps_milli
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
	DamageResolver.hit(world, world.enemies.index_of(target_id), def.turret_damage, 0, source)
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
