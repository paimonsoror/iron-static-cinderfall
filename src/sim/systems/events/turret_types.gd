class_name TurretTypes
extends RefCounted
## The turret types of the Archive's field options (CONTENT 8 and 12; `turrets{}` in data/weapons.json), for TurretSystem.
## Which type stands on a pad is a pure function of the run's unlocks (SimConfig.has_unlock), so it needs no state:
##
##   unlocks held                      pad 0          pad 1
##   none                              turret_gun     turret_gun
##   u_f_turret_arc                    turret_gun     turret_arc
##   u_f_turret_mortar                 turret_gun     turret_mortar
##   both                              turret_arc     turret_mortar
##
## (CONTENT 8 lets the player choose the type with one more tap when `turret_deploy` is drafted; that tap is a screen of
## its own and is not built, so the rule above places the types. An unlock is never without effect, and the first pad
## keeps the plain gun until both special types are owned.)
##
## turret_gun is the turret of ARCH 6.6 with the numbers of the auto_turret upgrade: TurretSystem fires it as before.
## turret_arc: the shot ignores armor and chains on to `chains` enemies within `chain_range_m`, each jump x `chain_falloff`.
## turret_mortar: no lock; when its cadence allows a shot it lobs a shell at the densest cluster between `min_range_m` and
## its range: a delayed area hit (`flight_s`, radius `area_m`, half damage at the edge) that leaves no pool.
## Every type takes the turret rules of the directives (rate, damage, range, sentry_link, overwatch) like the gun.

const GUN: StringName = &"turret_gun"
const ARC: StringName = &"turret_arc"
const MORTAR: StringName = &"turret_mortar"
const UNLOCK_ARC: String = "u_f_turret_arc"
const UNLOCK_MORTAR: String = "u_f_turret_mortar"
const MORTAR_EDGE_FRAC: float = 0.5
const MILLI_PER_SHOT: int = 60000


## The id of the turret type on `pad` (see the table above). The legacy content has the gun only.
static func id_of(world: SimWorld, pad: int) -> StringName:
	if world.content.run == null:
		return GUN
	var arc: bool = world.config.has_unlock(UNLOCK_ARC)
	var mortar: bool = world.config.has_unlock(UNLOCK_MORTAR)
	if pad <= 0:
		return ARC if arc and mortar else GUN
	if mortar:
		return MORTAR
	return ARC if arc else GUN


## The TurretTypeDef of a special type on `pad`; null for the plain gun (and for a type the content does not list).
static func special_of(world: SimWorld, pad: int) -> TurretTypeDef:
	var id: StringName = id_of(world, pad)
	if id == GUN:
		return null
	for t: TurretTypeDef in world.content.turret_types:
		if t.id == id:
			return t
	return null


## One number of the type's `params`, or `fallback`.
static func num(type: TurretTypeDef, key: StringName, fallback: float) -> float:
	return type.params.get(key, fallback)


## Range of the type with ModState.range_mul.
static func range_of(world: SimWorld, type: TurretTypeDef) -> float:
	return type.range_m * world.mods.range_mul


## The damage of one shot of `type` before armor on enemy `enemy_index` (-1 = nobody in particular): the type's damage x
## ModState.t_dmg_mul x the damage level of sentry_link x the overwatch bonus.
static func damage_of(world: SimWorld, type: TurretTypeDef, enemy_index: int, overwatch: bool) -> float:
	var damage_up: UpgradeDef = world.content.upgrades[Ids.UP_DAMAGE]
	var amount: float = type.damage * world.mods.t_dmg_mul
	amount *= 1.0 + damage_up.per_level * float(TurretRules.damage_level(world))
	return amount * TurretRules.damage_mul_vs(world, enemy_index, overwatch)


## One arc turret shot at the pad's target: the hit, then the chain. The caller has paid the shot and run the shot hook.
## Returns the damage dealt to the target.
static func fire_arc(world: SimWorld, type: TurretTypeDef, pad: int, overwatch: bool) -> float:
	var t: TurretStore = world.turrets
	var source: int = DamageSource.Id.TURRET_0 + pad
	var target: int = world.enemies.index_of(t.target_id[pad])
	if target < 0:
		return 0.0
	var flags: int = DamageResolver.F_IGNORE_ARMOR if num(type, &"armor_ignore", 0.0) >= 1.0 else 0
	var reach: float = num(type, &"chain_range_m", 0.0) * world.mods.area_mul
	var jumps: int = roundi(num(type, &"chains", 0.0))
	var falloff: float = num(type, &"chain_falloff", 1.0)
	var victims: PackedInt32Array = FireTargets.chain_victims(world, t.aim_x[pad], t.aim_z[pad], t.target_id[pad], jumps, reach)
	var dealt: float = DamageResolver.hit_ex(world, target, damage_of(world, type, target, overwatch), flags, source)
	var from_id: int = t.target_id[pad]
	var scale: float = 1.0
	for i: int in victims:
		var to_id: int = world.enemies.id[i]
		world.events.push(SimEventKind.Id.CHAIN_ARC, from_id, to_id)
		from_id = to_id
		scale *= falloff
		var _chained: float = DamageResolver.hit_ex(
			world, i, damage_of(world, type, i, overwatch) * scale, flags | DamageResolver.F_AREA, source
		)
	return dealt


## The mortar turret on `pad` for this tick: its cadence, and a shell at the densest cluster when a shot is due and a
## cluster stands between the minimum range and the range. It keeps no lock (target_id stays 0) and aims at the cluster.
static func step_mortar(world: SimWorld, type: TurretTypeDef, pad: int, rate_milli: int) -> void:
	var t: TurretStore = world.turrets
	t.fire_acc_milli[pad] = mini(MILLI_PER_SHOT, t.fire_acc_milli[pad] + roundi(float(type.sps_milli) * float(rate_milli) / 1000.0))
	t.target_id[pad] = 0
	t.lock_ticks_left[pad] = 0
	if t.fire_acc_milli[pad] < MILLI_PER_SHOT:
		return
	var radius: float = num(type, &"area_m", 0.0) * world.mods.area_mul
	var at: Vector2 = Targeting.pick_cluster(world, t.x[pad], t.z[pad], type.min_range_m, range_of(world, type), radius)
	if at == Vector2(t.x[pad], t.z[pad]):  # nothing in the band
		return
	var source: int = DamageSource.Id.TURRET_0 + pad
	t.fire_acc_milli[pad] -= MILLI_PER_SHOT
	t.aim_x[pad] = at.x
	t.aim_z[pad] = at.y
	world.combat.shots_by_source[source] += 1
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, 0)
	var flight: int = maxi(1, roundi(num(type, &"flight_s", 0.0) * float(SimWorld.TICK_RATE)))
	var _seq: int = HazardSystem.queue_hit(
		world, world.tick + flight, HazardState.K_SHELL, at.x, at.y, radius, damage_of(world, type, -1, false),
		MORTAR_EDGE_FRAC, DamageResolver.F_AREA, source
	)
