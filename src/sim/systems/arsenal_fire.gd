class_name ArsenalFire
extends RefCounted
## The shooting side of ArsenalSystem (VARIETY_SPEC 3.3): the dispatch from a weapon's firing kind to its fire file with
## the weapon specials that belong to no single kind, the cadence of this tick, the per-tick bookkeeping of the weapons
## that remember (LMG spin-up, torch ramp) and the off-hand fire of the twin_link directive.
##
## Pistol, level 3 (CONTENT 2): every 6th shot is a guaranteed x3 hit (a hit with the damage tripled, so armor is taken off
## once). LMG: the rate ramps from `sps_min` to the full rate over `spin_up_s` of continuous fire (the target held, the
## magazine not empty; ArsenalState.spin_ticks) and starts over after SPIN_IDLE_RESET_TICKS without it (idle_ticks);
## `stray_chance` of the shots (the `aim` stream) go to a random other enemy within STRAY_REACH_M of the target, and every
## hit strips `armor_shred` armor from its victim, up to SHRED_CAP_MILLI (EnemyExtState.shred_milli, which
## DamageResolver.effective_armor already subtracts). Fuel drums as stray victims wait for the drums of V4-V.
## twin_link: the holstered weapon (the lowest other filled slot) fires at OFFHAND_RATE_MILLI of its rate at the
## Warden's target, if that is in the weapon's range, with its own magazine or heat, as DamageSource.WARDEN_OFFHAND.
## Only the kinds that resolve in one call fire from the holster (not the rail lance, which needs its charge, nor the
## torch, which needs its ramp).

const OFFHAND_RATE_MILLI: int = 350  ## 35% of the holstered weapon's rate
const SPIN_IDLE_RESET_TICKS: int = 60  ## 1.0 s without firing starts the LMG's spin-up again
const SHRED_CAP_MILLI: int = 6000  ## at most 6 armor stripped from one enemy
const STRAY_REACH_M: float = 1.5
const OFFHAND_KINDS: Array[int] = [
	WeaponDef.Kind.HITSCAN, WeaponDef.Kind.CONE, WeaponDef.Kind.ARC, WeaponDef.Kind.SHELL, WeaponDef.Kind.MISSILES,
]


## Shots per second x 1000 of the active weapon this tick: its rate (ArsenalSystem.sps_milli) with the LMG's spin-up and
## the kill chain.
static func rate_milli(world: SimWorld, a: ArsenalState, def: WeaponDef) -> int:
	var rate: int = ArsenalSystem.sps_milli(world, def)
	if def.spin_up_ticks > 0 and def.sps_min_milli > 0 and def.sps_milli > 0:
		var low: float = float(def.sps_min_milli) / float(def.sps_milli)
		var spun: float = minf(1.0, float(a.spin_ticks) / float(def.spin_up_ticks))
		rate = roundi(float(rate) * (low + (1.0 - low) * spun))
	var chain: int = ShotHooks.kill_chain_mult_milli(a)
	if chain != 1000:
		rate = roundi(float(rate) * float(chain) / 1000.0)
	return rate


## End-of-tick bookkeeping of the active weapon; `engaged` = it holds a target and may fire this tick.
static func track(a: ArsenalState, def: WeaponDef, engaged: bool) -> void:
	if def.spin_up_ticks > 0:
		if engaged:
			a.spin_ticks = mini(def.spin_up_ticks, a.spin_ticks + 1)
			a.idle_ticks = 0
		else:
			a.idle_ticks = mini(SPIN_IDLE_RESET_TICKS, a.idle_ticks + 1)
			if a.idle_ticks >= SPIN_IDLE_RESET_TICKS:
				a.spin_ticks = 0
	else:
		a.spin_ticks = 0
		a.idle_ticks = 0
	if def.kind != WeaponDef.Kind.BEAM or not engaged:
		a.beam_target = 0
		a.beam_hits = 0
	if def.kind != WeaponDef.Kind.LINE:
		a.charge_left = 0


## One shot of `def` (the effective def of the weapon in `slot`) at the Warden's target. True when a shot left the weapon.
static func shoot(world: SimWorld, a: ArsenalState, slot: int, def: WeaponDef, source: int) -> bool:
	ShotHooks.shooter_slot = slot
	var fired: bool = false
	match def.kind:
		WeaponDef.Kind.HITSCAN:
			fired = _bullet(world, a, slot, def, source)
		WeaponDef.Kind.CONE:
			fired = FireCone.fire(world, slot, def, source)
		WeaponDef.Kind.ARC:
			fired = FireArc.fire(world, slot, def, source)
		WeaponDef.Kind.LINE:
			fired = FireLine.fire(world, slot, def, source)
		WeaponDef.Kind.SHELL:
			fired = FireShell.fire(world, slot, def, source)
		WeaponDef.Kind.MISSILES:
			fired = FireMissiles.fire(world, slot, def, source)
		WeaponDef.Kind.BEAM:
			fired = FireBeam.fire(world, slot, def, source)
	ShotHooks.shooter_slot = -1
	return fired


## Starts the pool of every mortar shell that HazardSystem will land on this tick (it runs after the weapon step). The
## queue is sorted by (due, sequence) and at most RunDef.max_blasts_per_tick hits land per tick, so the first entries that
## are due and of kind K_SHELL from the Warden are exactly the shells landing now. The pool has the numbers of the mortar
## in the Warden's slots (its level counts), else of the plain data entry. Stand-in for a landing hook in HazardSystem.
static func start_landing_pools(world: SimWorld) -> void:
	var h: HazardState = world.hazards
	if h.q_due.is_empty():
		return
	var run: RunDef = world.content.run
	var limit: int = run.max_blasts_per_tick if run != null else HazardSystem.DEFAULT_MAX_PER_TICK
	for k: int in mini(limit, h.q_due.size()):
		if h.q_due[k] > world.tick:
			break
		var from_warden: bool = h.q_source[k] == DamageSource.Id.WARDEN or h.q_source[k] == DamageSource.Id.WARDEN_OFFHAND
		if h.q_kind[k] != HazardState.K_SHELL or not from_warden:
			continue
		var slot: int = ArsenalSystem.slot_of(world, Ids.WP_SLAG_MORTAR)
		var def: WeaponDef = world.content.weapons[Ids.WP_SLAG_MORTAR]
		if slot >= 0:
			def = ArsenalSystem.effective_of(world, slot)
		if def.pool_ticks > 0:
			var _pool: int = HazardSystem.add_pool(
				world, h.q_x[k], h.q_z[k], def.pool_radius_m * world.mods.area_mul, def.pool_ticks, def.pool_dps, def.pool_slow
			)


## The holstered weapon fires (twin_link). Called once per tick after the active weapon.
static func step_offhand(world: SimWorld, a: ArsenalState, active_slot: int) -> void:
	if ShotHooks.stacks(world, ShotHooks.D_TWIN_LINK) <= 0:
		return
	var off: int = _offhand_slot(a, active_slot)
	if off < 0:
		return
	var def: WeaponDef = ArsenalSystem.effective_of(world, off)
	if not OFFHAND_KINDS.has(def.kind):
		return
	var rate: int = roundi(float(ArsenalSystem.sps_milli(world, def)) * float(OFFHAND_RATE_MILLI) / 1000.0)
	a.offhand_acc_milli = mini(ArsenalSystem.MILLI_PER_SHOT, a.offhand_acc_milli + rate)
	var w: WardenState = world.warden
	var range_m: float = ArsenalSystem.range_of(world, def)
	while a.offhand_acc_milli >= ArsenalSystem.MILLI_PER_SHOT and w.target_id != 0 and _ready(a, off, def):
		if not Targeting.is_valid(world, w.target_id, w.x, w.z, range_m):
			break
		if not shoot(world, a, off, def, DamageSource.Id.WARDEN_OFFHAND):
			break
		a.offhand_acc_milli -= ArsenalSystem.MILLI_PER_SHOT
		world.combat.shots_by_source[DamageSource.Id.WARDEN_OFFHAND] += 1
		_pay_offhand(world, a, off, def)


static func _offhand_slot(a: ArsenalState, active_slot: int) -> int:
	for s: int in a.slot_count:
		if s != active_slot and a.slot_weapon[s] >= 0:
			return s
	return -1


static func _ready(a: ArsenalState, slot: int, def: WeaponDef) -> bool:
	if def.is_heat():
		return a.slot_vent_left[slot] == 0
	return a.slot_reload_left[slot] == 0 and a.slot_magazine[slot] > 0


## A round or heat for the holstered weapon; an empty magazine starts a reload (at the holster speed, no event).
static func _pay_offhand(world: SimWorld, a: ArsenalState, slot: int, def: WeaponDef) -> void:
	if def.is_heat():
		a.slot_cool_acc[slot] = 0
		a.slot_heat[slot] += def.heat_per_shot
		var cap: int = ArsenalSystem.heat_cap_of(world, slot)
		if a.slot_heat[slot] >= cap:
			a.slot_heat[slot] = cap
			a.slot_vent_left[slot] = ArsenalSystem.vent_ticks_of(world, def)
			world.events.push(SimEventKind.Id.WEAPON_VENTED, slot, a.slot_vent_left[slot])
		return
	a.slot_magazine[slot] -= 1
	if a.slot_magazine[slot] <= 0:
		a.slot_reload_left[slot] = ArsenalSystem.reload_ticks_of(world, def) + ShotHooks.reload_jam_ticks(world)
		a.slot_reload_acc[slot] = 0


## The hitscan weapons: the pistol's perk and the LMG's strays and shred around FireHitscan.
static func _bullet(world: SimWorld, a: ArsenalState, slot: int, def: WeaponDef, source: int) -> bool:
	var fire_def: WeaponDef = def
	var level: int = a.slot_level[slot]
	var every: int = roundi(WeaponPerks.level_value(def, level, &"crit_every", 0.0))
	if every > 0 and ShotHooks.pistol_crit_due(a, every):
		fire_def = WeaponPerks.scaled(def, WeaponPerks.level_value(def, level, &"crit_mult", 1.0))
	if def.stray_chance <= 0.0 and def.armor_shred <= 0.0:
		return FireHitscan.fire(world, slot, fire_def, source)
	return _suppressor(world, slot, fire_def, source)


## One LMG round: it may stray to a neighbour of the target (FireHitscan takes the Warden's target, so the target is
## swapped for the round and put back), and it strips armor from whoever it hit.
static func _suppressor(world: SimWorld, slot: int, def: WeaponDef, source: int) -> bool:
	var w: WardenState = world.warden
	var store: EnemyStore = world.enemies
	var target_id: int = w.target_id
	var target: int = store.index_of(target_id)
	if target < 0:
		return false
	var victim_id: int = target_id
	if def.stray_chance > 0.0:
		var rng: RandomNumberGenerator = world.rng.stream(&"aim")
		if rng.randf() < def.stray_chance:
			var near: PackedInt32Array = PackedInt32Array()
			var _n: int = AreaDamage.query(world, store.x[target], store.z[target], STRAY_REACH_M, near)
			var self_at: int = near.find(target)
			if self_at >= 0:
				near.remove_at(self_at)
			if not near.is_empty():
				victim_id = store.id[near[rng.randi_range(0, near.size() - 1)]]
	w.target_id = victim_id
	var fired: bool = FireHitscan.fire(world, slot, def, source)
	w.target_id = target_id
	if fired and def.armor_shred > 0.0:
		var victim: int = store.index_of(victim_id)
		if victim >= 0:
			var shred: int = world.ext.shred_milli[victim] + roundi(def.armor_shred * 1000.0)
			world.ext.shred_milli[victim] = mini(SHRED_CAP_MILLI, shred)
	return fired
