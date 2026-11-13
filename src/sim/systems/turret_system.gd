class_name TurretSystem
extends RefCounted
## Auto turrets (ARCH 6.6; GDD 5.3). No magazine, no reload, damage level 0, own range and lock, unaffected
## by fire_rate and Overdrive (except through the directive flag `od_turrets`), but armor_piercing applies
## (DamageResolver). Pads are processed in index order; a hit's source is TURRET_0 + pad.
##
## Variety content (VARIETY_SPEC 7.4): while the turrets are offline (a brownout after a Core Surge, the Low Power
## modifier, a Tremor Rig stomp: EventState.turret_offline_ticks, counted down by EventSystem) nothing happens, not even
## the fire accumulator. The fire rate of a pad is EventRates.turret_rate_milli (Core Surge x2, ModState.t_rate_mul,
## sentry_link, last_stand_protocol, od_turrets, a jammer aura), the damage is multiplied by ModState.t_dmg_mul and gets the
## damage level sentry_link gives, the range is multiplied by ModState.range_mul, overwatch picks elites and specialists
## first (+40% to them) and mine_layer lays mines (TurretRules). With the neutral values of the legacy content every number
## is the base one.

const MILLI_PER_SHOT: int = 60000


static func step(world: SimWorld) -> void:
	var def: UpgradeDef = world.content.upgrades[Ids.UP_AUTO_TURRET]
	var turrets: TurretStore = world.turrets
	if EventRates.turrets_offline(world) or world.turrets.active_count() == 0:
		return
	var overwatch: bool = TurretRules.overwatch(world)
	TurretRules.lay_mines(world)
	for pad: int in turrets.active.size():
		if turrets.active[pad] == 1:
			_step_pad(world, def, pad, overwatch)


static func _step_pad(world: SimWorld, def: UpgradeDef, pad: int, overwatch: bool) -> void:
	var t: TurretStore = world.turrets
	var rate: int = EventRates.turret_rate_milli(world, pad)
	if rate == EventRates.RATE_ONE:
		t.fire_acc_milli[pad] += def.turret_sps_milli
	else:
		t.fire_acc_milli[pad] += roundi(float(def.turret_sps_milli) * float(rate) / 1000.0)
	var range_m: float = TurretRules.range_of(world, def)
	var lock: PackedInt32Array = Targeting.refresh_lock(
		world, t.target_id[pad], t.lock_ticks_left[pad], t.x[pad], t.z[pad], range_m, def.turret_lock_ticks
	)
	t.target_id[pad] = lock[0]
	t.lock_ticks_left[pad] = lock[1]
	if overwatch:
		_overwatch(world, def, pad, range_m)
	_aim(world, t, pad)
	while t.fire_acc_milli[pad] >= MILLI_PER_SHOT and t.target_id[pad] != 0:
		_fire(world, def, pad, overwatch)
	if t.fire_acc_milli[pad] > MILLI_PER_SHOT:
		t.fire_acc_milli[pad] = MILLI_PER_SHOT


## One shot at the pad's target. The shot hook (arc_pylons) runs once the shot is tallied, the hit hook (flak_heads) once
## the target took the hit, before the pad looks for a new target, so the splash lands where the target stood. Re-picks at
## once when the shot killed it.
static func _fire(world: SimWorld, def: UpgradeDef, pad: int, overwatch: bool) -> void:
	var t: TurretStore = world.turrets
	var source: int = DamageSource.Id.TURRET_0 + pad
	var target_id: int = t.target_id[pad]
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, target_id)
	t.fire_acc_milli[pad] -= MILLI_PER_SHOT
	world.combat.shots_by_source[source] += 1
	ShotHooks.on_turret_shot(world, pad, world.enemies.index_of(target_id))
	var hit_index: int = world.enemies.index_of(target_id)
	var amount: float = def.turret_damage * world.mods.t_dmg_mul * TurretRules.damage_mul_vs(world, hit_index, overwatch)
	var dealt: float = DamageResolver.hit(world, hit_index, amount, TurretRules.damage_level(world), source)
	if hit_index >= 0:
		ShotHooks.on_turret_hit(world, pad, hit_index, dealt)
	if world.enemies.index_of(target_id) < 0:
		var picked: int = Targeting.pick(world, t.x[pad], t.z[pad], TurretRules.range_of(world, def))
		t.target_id[pad] = picked
		t.lock_ticks_left[pad] = def.turret_lock_ticks if picked != 0 else 0
		_aim(world, t, pad)


## overwatch: a pad whose target is not an elite or a specialist swaps to the best one in range, if there is one.
static func _overwatch(world: SimWorld, def: UpgradeDef, pad: int, range_m: float) -> void:
	var t: TurretStore = world.turrets
	var current: int = world.enemies.index_of(t.target_id[pad])
	if current >= 0 and TurretRules.is_priority(world, current):
		return
	var priority: int = TurretRules.priority_target(world, t.x[pad], t.z[pad], range_m)
	if priority != 0:
		t.target_id[pad] = priority
		t.lock_ticks_left[pad] = def.turret_lock_ticks


static func _aim(world: SimWorld, t: TurretStore, pad: int) -> void:
	var i: int = world.enemies.index_of(t.target_id[pad])
	if i >= 0:
		t.aim_x[pad] = world.enemies.x[i]
		t.aim_z[pad] = world.enemies.z[i]
