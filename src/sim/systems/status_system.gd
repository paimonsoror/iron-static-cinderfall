class_name StatusSystem
extends RefCounted
## Per-enemy statuses (tick step 7): slow, burn, wards, auras, reclaimer tethers, the borer's breach, elite upkeep.
## Writes EnemyExtState and the derived tables of NavState (speed_mul, period_mul, cover). Called every tick of a live
## run, after AbilitySystem (so a stun of this tick is seen) and before MovementSystem (which reads speed_mul).
##
## Burn: `burn_ticks` counts down every tick; a burning enemy takes a pulse of half a second of damage on every tick
## where (tick + enemy id) is a multiple of PULSE_TICKS, so a burn that is refreshed by every hit still deals its
## damage and a 3 s burn of 8 per second deals exactly 24. No float accumulates (VARIETY_SPEC 9.5 rule 4).
## Slow: the stronger slow wins and never stacks; it scales the enemy's displacement while `slow_ticks` runs.
## Wards (CONTENT 4.2, 4.3): `ward_milli` is the pool of a shieldbearer (it protects the others around it, never
## itself) or the personal ward of a WARDED elite. `absorb` is the damage filter DamageResolver.hit_ex applies after
## armor; a pool refills fully after its regeneration time without absorbing; a stun (the EMP) empties it and holds
## the refill for the stun plus that time.
## Breach (the borer): a type with `breach_delay_s` that spawns exactly on a breach point of the arena stays under the
## ground (F_EMERGING, `aux_cd` ticks left: the telegraph) and then comes out; until then it does not move, cannot be
## targeted and takes no damage.
## Deaths: `on_enemy_killed` is the hook for what a death causes by type or affix (the splitter's shards, the jammer's
## stun, the VOLATILE blast); DeathHooks.on_killed calls it before the store slot is freed.

const PULSE_TICKS: int = 30
const DEFAULT_BURN_TICKS: int = 180
## `NavState.t_special` bits: the enemy types this system has work for.
const SP_BEARER: int = 1  ## `ward_pool`: the shieldbearer
const SP_RECLAIMER: int = 2  ## `tether_count`
const SP_BREACH: int = 4  ## `breach_delay_s`: the borer
const SP_JAMMER: int = 8  ## `aura_radius` with `cooldown_rate`
## Flags that need no upkeep here.
const F_PLAIN: int = EnemyExtState.F_MINI | EnemyExtState.F_ARMED | EnemyExtState.F_FIRED
## A hit that ignores armor drains a ward this many times as fast (GDD 6.3 `ward_mult`; arc, torch).
const WARD_DRAIN_IGNORE_ARMOR: float = 3.0
const DEFAULT_WARD_REGEN_S: float = 4.0

## The healer of the heal in progress (an enemy id, 0 = none): DamageResolver.heal reports it in ENEMY_HEALED.
static var healer_id: int = 0


static func step(world: SimWorld) -> void:
	if world.content.run == null:
		return
	var store: EnemyStore = world.enemies
	var ext: EnemyExtState = world.ext
	var nav: NavState = world.nav
	nav.speed_mul.fill(1.0)
	nav.period_mul.fill(1.0)
	nav.cover.fill(-1)
	var alive: PackedByteArray = store.alive
	var types: PackedByteArray = store.type
	var flags: PackedInt32Array = ext.flags
	var slow: PackedInt32Array = ext.slow_ticks
	var burning: PackedInt32Array = ext.burn_ticks
	var special: PackedByteArray = nav.t_special
	var bearers: PackedInt32Array = PackedInt32Array()
	var clocks: PackedInt32Array = PackedInt32Array()
	for i: int in store.high_water:
		if alive[i] == 0:
			continue
		if slow[i] > 0:
			slow[i] -= 1
			nav.speed_mul[i] = 1.0 - float(ext.slow_milli[i]) / 1000.0
			if slow[i] == 0:
				ext.slow_milli[i] = 0
		if burning[i] > 0:
			burning[i] -= 1
			if (world.tick + store.id[i]) % PULSE_TICKS == 0:
				var pulse: float = float(ext.burn_milli[i]) * float(PULSE_TICKS) / 60000.0
				DamageResolver.hit_ex(world, i, pulse, DamageResolver.F_BURN | DamageResolver.F_AREA, DamageSource.Id.HAZARD)
				if alive[i] == 0:
					continue
		var f: int = flags[i]
		var sp: int = special[types[i]]
		if (f & ~F_PLAIN) == 0 and sp == 0:
			continue
		if sp != 0:
			_special_tick(world, i, sp, bearers)
		if (f & EnemyExtState.F_ELITE) != 0:
			_elite_tick(world, i, sp, clocks)
	if not clocks.is_empty():
		AuraFields.overclock(world, clocks)
	if not bearers.is_empty():
		AuraFields.cover(world, bearers)


## The `NavState.t_special` bits of an enemy type.
static func special_bits(def: EnemyDef) -> int:
	var bits: int = 0
	if def.beh(&"ward_pool") > 0.0:
		bits |= SP_BEARER
	if def.beh(&"tether_count") > 0.0:
		bits |= SP_RECLAIMER
	if def.beh(&"breach_delay_s") > 0.0:
		bits |= SP_BREACH
	if def.beh(&"aura_radius") > 0.0 and def.beh(&"cooldown_rate") > 0.0:
		bits |= SP_JAMMER
	return bits


## Slows an enemy by `milli` / 1000 of its speed for `ticks` (the stronger slow wins, never stacks). An ANCHORED elite
## is immune.
static func apply_slow(world: SimWorld, enemy_index: int, ticks: int, milli: int) -> void:
	var ext: EnemyExtState = world.ext
	if enemy_index < 0 or enemy_index >= ext.capacity or world.enemies.alive[enemy_index] == 0:
		return
	if ticks <= 0 or milli <= 0 or EliteSystem.is_anchored(world, enemy_index):
		return
	var strength: int = mini(milli, 1000)
	if ext.slow_ticks[enemy_index] <= 0 or strength > ext.slow_milli[enemy_index]:
		ext.slow_milli[enemy_index] = strength
		ext.slow_ticks[enemy_index] = ticks
	elif strength == ext.slow_milli[enemy_index]:
		ext.slow_ticks[enemy_index] = maxi(ext.slow_ticks[enemy_index], ticks)


## Stuns an enemy for `ticks` unless it is ANCHORED or stun-immune; a longer stun replaces a shorter one. Pushes
## ENEMY_STUNNED. True when the stun was set.
static func apply_stun(world: SimWorld, enemy_index: int, ticks: int) -> bool:
	var store: EnemyStore = world.enemies
	if enemy_index < 0 or enemy_index >= store.capacity or store.alive[enemy_index] == 0 or ticks <= 0:
		return false
	if store.stun_immune_ticks[enemy_index] > 0 or EliteSystem.is_anchored(world, enemy_index):
		return false
	if ticks <= store.stun_ticks[enemy_index]:
		return false
	store.stun_ticks[enemy_index] = ticks
	world.events.push(SimEventKind.Id.ENEMY_STUNNED, store.id[enemy_index], ticks)
	return true


## Ignites an enemy: `dps_milli` damage per second x 1000 for `ticks` (refreshes, does not stack).
static func apply_burn(world: SimWorld, enemy_index: int, ticks: int, dps_milli: int) -> void:
	if enemy_index < 0 or enemy_index >= world.ext.capacity or world.enemies.alive[enemy_index] == 0:
		return
	if ticks <= 0 or dps_milli <= 0:
		return
	world.ext.burn_ticks[enemy_index] = ticks
	world.ext.burn_milli[enemy_index] = dps_milli


## The burn of `incendiary_tips` (ModState.burn_dps > 0) on an enemy the Warden just hit.
static func ignite(world: SimWorld, enemy_index: int) -> void:
	var dps: float = world.mods.burn_dps
	if dps <= 0.0:
		return
	apply_burn(world, enemy_index, burn_ticks(world), roundi(dps * 1000.0))


## How long a burn lasts (data/events.json hazards.burn.seconds).
static func burn_ticks(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null or not run.hazards.has(&"burn"):
		return DEFAULT_BURN_TICKS
	var burn: Dictionary = run.hazards[&"burn"]
	if not burn.has(&"seconds"):
		return DEFAULT_BURN_TICKS
	var seconds: float = burn[&"seconds"]
	return Formulas.ticks(seconds)


## The ward filter of one hit (DamageResolver.hit_ex applies it after armor, before debug_damage_mult): `amount` is the
## damage that would reach the hp of `enemy_index`; returns what is left of it. In order: a body under the ground
## takes nothing; the hit restarts a REGENERATING elite's delay; with F_NO_WARD nothing else happens; a shieldbearer
## covering the enemy blocks 1 - `ward_mult` of it while its pool lasts (the blocked damage drains the pool); then the
## enemy's own WARDED ward absorbs what it can. A hit with F_IGNORE_ARMOR drains wards WARD_DRAIN_IGNORE_ARMOR times
## as fast. Pushes WARD_CHANGED and WARD_BROKEN.
static func absorb(world: SimWorld, enemy_index: int, amount: float, flags: int) -> float:
	if world.content.run == null or amount <= 0.0:
		return amount
	var ext: EnemyExtState = world.ext
	var nav: NavState = world.nav
	var own: int = ext.flags[enemy_index]
	if (own & EnemyExtState.F_EMERGING) != 0:
		return 0.0
	if (own & EnemyExtState.F_ELITE) != 0 and EliteSystem.has(world, enemy_index, EliteSystem.A_REGEN):
		ext.fuse_ticks[enemy_index] = EliteSystem.REGEN_DELAY_TICKS
	if (flags & DamageResolver.F_NO_WARD) != 0:
		return amount
	var drain: float = WARD_DRAIN_IGNORE_ARMOR if (flags & DamageResolver.F_IGNORE_ARMOR) != 0 else 1.0
	var left: float = amount
	var store: EnemyStore = world.enemies
	var bearer: int = nav.cover[enemy_index]
	if bearer >= 0 and bearer != enemy_index and store.alive[bearer] == 1 and ext.ward_milli[bearer] > 0:
		if (nav.t_special[store.type[bearer]] & SP_BEARER) != 0:
			var keep: float = clampf(world.content.enemies[store.type[bearer]].beh(&"ward_mult", 0.4), 0.0, 1.0)
			left -= _drain(world, bearer, left * (1.0 - keep), drain)
	if ext.ward_milli[enemy_index] > 0 and (nav.t_special[store.type[enemy_index]] & SP_BEARER) == 0:
		left -= _drain(world, enemy_index, left, drain)
	return maxf(0.0, left)


## The full ward of the enemy at `enemy_index` in thousandths: a shieldbearer's `ward_pool`, plus WARD_FRAC of max HP
## for a WARDED elite (on a shieldbearer the two make one bigger pool). 0 = it has no ward.
static func ward_max_milli(world: SimWorld, enemy_index: int) -> int:
	var store: EnemyStore = world.enemies
	var total: float = world.content.enemies[store.type[enemy_index]].beh(&"ward_pool")
	if world.ext.affix_mask[enemy_index] != 0 and EliteSystem.has(world, enemy_index, EliteSystem.A_WARDED):
		total += store.max_hp[enemy_index] * EliteSystem.WARD_FRAC
	return roundi(total * 1000.0)


## Ticks without absorbing after which the ward of `enemy_index` refills.
static func ward_regen_ticks(world: SimWorld, enemy_index: int) -> int:
	var def: EnemyDef = world.content.enemies[world.enemies.type[enemy_index]]
	if def.beh(&"ward_pool") > 0.0:
		return maxi(1, Formulas.ticks(def.beh(&"ward_regen_s", DEFAULT_WARD_REGEN_S)))
	return EliteSystem.WARD_REGEN_TICKS


## Restores up to `amount` hp of the enemy at `enemy_index` through DamageResolver.heal (the only writer of hp), with
## `healer` (an enemy id) as the source of ENEMY_HEALED. Returns the hp restored.
static func heal_enemy(world: SimWorld, healer: int, enemy_index: int, amount: float) -> float:
	healer_id = healer
	var restored: float = DamageResolver.heal(world, enemy_index, amount)
	healer_id = 0
	return restored


## What the death of the enemy at `enemy_index` causes by its type and affixes (it is still in the store): a splitter
## breaks into its shards, a jammer stuns its neighbours, a VOLATILE elite queues its blast.
static func on_enemy_killed(world: SimWorld, enemy_index: int, source: int) -> void:
	if world.content.run == null:
		return
	var store: EnemyStore = world.enemies
	var def: EnemyDef = world.content.enemies[store.type[enemy_index]]
	var stun_radius: float = def.beh(&"death_stun_radius")
	if stun_radius > 0.0:
		var ticks: int = Formulas.ticks(def.beh(&"death_stun_s"))
		var near: PackedInt32Array = PackedInt32Array()
		AreaDamage.query(world, store.x[enemy_index], store.z[enemy_index], stun_radius, near)
		for j: int in near:
			if j != enemy_index:
				apply_stun(world, j, ticks)
	if def.beh(&"split_count") > 0.0:
		_split(world, enemy_index, def)
	EliteSystem.on_killed(world, enemy_index, source)


## The factor ability cooldowns tick at now: the lowest `cooldown_rate` of the living jammers, 1.0 without one
## (CONTENT 4.2: 0.7 while at least one jammer lives). AbilitySystem multiplies its countdown by it.
static func cooldown_rate(world: SimWorld) -> float:
	return AuraFields.jam_cooldown_rate(world) if world.content.run != null else 1.0


## The fire-rate factor of the turret on pad `pad`: `turret_rate_mult` (0.5) while the pad stands inside a living
## jammer's `aura_radius`, else 1.0. TurretSystem multiplies its cadence by it.
static func turret_rate_mult(world: SimWorld, pad: int) -> float:
	if world.content.run == null or pad < 0 or pad >= world.turrets.x.size():
		return 1.0
	return AuraFields.jam_turret_rate(world, world.turrets.x[pad], world.turrets.z[pad])


## Takes `want` damage off a hit at the cost of `want * drain_mult` of the ward of `holder`; a ward that cannot pay it
## all blocks what it can and breaks. Restarts the ward's refill time. Returns the damage blocked.
static func _drain(world: SimWorld, holder: int, want: float, drain_mult: float) -> float:
	if want <= 0.0:
		return 0.0
	var ext: EnemyExtState = world.ext
	var pool: float = float(ext.ward_milli[holder]) / 1000.0
	var cost: float = want * drain_mult
	var blocked: float = want
	var enemy_id: int = world.enemies.id[holder]
	var full: float = float(ward_max_milli(world, holder)) / 1000.0
	ext.ward_regen_cd[holder] = ward_regen_ticks(world, holder)
	if cost >= pool:
		blocked = pool / drain_mult
		ext.ward_milli[holder] = 0
		world.events.push(SimEventKind.Id.WARD_CHANGED, enemy_id, 0, 0.0, full)
		world.events.push(SimEventKind.Id.WARD_BROKEN, enemy_id)
	else:
		ext.ward_milli[holder] = maxi(1, ext.ward_milli[holder] - roundi(cost * 1000.0))
		world.events.push(SimEventKind.Id.WARD_CHANGED, enemy_id, 0, float(ext.ward_milli[holder]) / 1000.0, full)
	return blocked


## One tick of a ward: a stunned holder loses it and its refill waits; otherwise an emptied or drained ward counts its
## refill time down and comes back whole.
static func _ward_tick(world: SimWorld, i: int) -> void:
	var ext: EnemyExtState = world.ext
	var full: int = ward_max_milli(world, i)
	if full <= 0:
		return
	if world.enemies.stun_ticks[i] > 0:
		if ext.ward_milli[i] > 0:
			ext.ward_milli[i] = 0
			world.events.push(SimEventKind.Id.WARD_CHANGED, world.enemies.id[i], 0, 0.0, float(full) / 1000.0)
			world.events.push(SimEventKind.Id.WARD_BROKEN, world.enemies.id[i])
		ext.ward_regen_cd[i] = ward_regen_ticks(world, i)
		return
	if ext.ward_milli[i] >= full:
		return
	ext.ward_regen_cd[i] -= 1
	if ext.ward_regen_cd[i] <= 0:
		ext.ward_regen_cd[i] = 0
		ext.ward_milli[i] = full
		world.events.push(SimEventKind.Id.WARD_CHANGED, world.enemies.id[i], 0, float(full) / 1000.0, float(full) / 1000.0)


## The per-tick work of a special type: the borer's breach, the shieldbearer's pool, the reclaimer's tethers.
static func _special_tick(world: SimWorld, i: int, sp: int, bearers: PackedInt32Array) -> void:
	var ext: EnemyExtState = world.ext
	var store: EnemyStore = world.enemies
	if (sp & SP_BREACH) != 0:
		if (ext.flags[i] & EnemyExtState.F_EMERGING) != 0:
			ext.aux_cd[i] -= 1
			if ext.aux_cd[i] <= 0:
				ext.aux_cd[i] = 0
				ext.flags[i] &= ~EnemyExtState.F_EMERGING
		elif store.spawn_tick[i] == world.tick and _on_breach_point(world, store.x[i], store.z[i]):
			begin_breach(world, i)
	if (sp & SP_BEARER) != 0:
		_ward_tick(world, i)
		bearers.append(i)
	if (sp & SP_RECLAIMER) != 0 and store.state[i] == EnemyStore.ST_ATTACKING and store.stun_ticks[i] <= 0:
		if (world.tick + store.id[i]) % PULSE_TICKS == 0:
			var targets: PackedInt32Array = PackedInt32Array()
			AuraFields.tether_targets(world, i, targets)
			var amount: float = AuraFields.tether_pulse(world, world.content.enemies[store.type[i]], PULSE_TICKS)
			for j: int in targets:
				heal_enemy(world, store.id[i], j, amount)


## Puts the enemy at `enemy_index` under the ground for its type's `breach_delay_s` (the breach telegraph).
static func begin_breach(world: SimWorld, enemy_index: int) -> void:
	var def: EnemyDef = world.content.enemies[world.enemies.type[enemy_index]]
	var ticks: int = Formulas.ticks(def.beh(&"breach_delay_s"))
	if ticks <= 0:
		return
	world.ext.flags[enemy_index] |= EnemyExtState.F_EMERGING
	world.ext.aux_cd[enemy_index] = ticks


## The per-tick work of an elite: ANCHORED shrugs off a stun, SWIFT speed, the WARDED ward, REGENERATING, and the
## list of overclockers whose aura is on (a stunned one gives none).
static func _elite_tick(world: SimWorld, i: int, sp: int, clocks: PackedInt32Array) -> void:
	var mask: int = world.ext.affix_mask[i]
	if mask == 0:
		return
	var aff: PackedInt32Array = world.nav.aff
	var store: EnemyStore = world.enemies
	if (mask & aff[EliteSystem.A_ANCHORED]) != 0 and store.stun_ticks[i] > 0:
		store.stun_ticks[i] = 0
	world.nav.speed_mul[i] *= EliteSystem.stat(world.content, mask, &"speed_mul", 1.0)
	if (mask & aff[EliteSystem.A_WARDED]) != 0 and (sp & SP_BEARER) == 0:
		_ward_tick(world, i)
	if (mask & aff[EliteSystem.A_REGEN]) != 0:
		EliteSystem.regen_tick(world, i)
	if (mask & aff[EliteSystem.A_OVERCLOCK]) != 0 and store.stun_ticks[i] <= 0:
		clocks.append(i)


static func _on_breach_point(world: SimWorld, x: float, z: float) -> bool:
	for p: Vector2 in world.content.arena.breach_points:
		if is_equal_approx(p.x, x) and is_equal_approx(p.y, z):
			return true
	return false


## The splitter's death: `split_count` bodies of `split_type` on a ring of `split_ring_m` around the death position
## (fenced out of props, the core and the grid border). A shard that finds its cap full joins the spawn queue at that
## spot (VARIETY_SPEC 5.5). Pushes ENEMY_SPLIT(enemy id, children, x, z).
static func _split(world: SimWorld, enemy_index: int, def: EnemyDef) -> void:
	var store: EnemyStore = world.enemies
	var nav: NavState = world.nav
	var child: int = roundi(def.beh(&"split_type", -1.0))
	var count: int = roundi(def.beh(&"split_count"))
	if child < 0 or child >= world.content.enemies.size() or count <= 0:
		return
	var x: float = store.x[enemy_index]
	var z: float = store.z[enemy_index]
	var ring: float = def.beh(&"split_ring_m")
	var clear: float = nav.t_clear[child]
	for k: int in count:
		var angle: float = TAU * float(k) / float(count)
		NavSteering.fence(nav, world.content.arena, clear, x, z, x + ring * cos(angle), z + ring * sin(angle))
		var cx: float = nav.fix[0]
		var cz: float = nav.fix[1]
		var j: int = world.spawn_enemy(child, cx, cz)
		if j < 0:
			SpawnSystem.enqueue(world, child, cx, cz)
			continue
		store.path_dist[j] = nav.path_dist_of(store, j)
		nav.track(j, store.id[j], store.path_dist[j])
	world.events.push(SimEventKind.Id.ENEMY_SPLIT, store.id[enemy_index], count, x, z)
