class_name CoreAttackSystem
extends RefCounted
## Enemies standing in their attack slot hit the core, shield first (ARCH 6.6; GDD 6).
##
## Every alive ST_ATTACKING enemy that is not stunned counts attack_cd down by one; at 0 it hits for
## core_damage and the timer restarts at attack_period_ticks. A stunned enemy's timer is frozen. Hits that
## land on the same tick are applied in ascending enemy id order, so the shield is spent deterministically.
##
## Variety content (VARIETY_SPEC 5.1, 5.4; CONTENT 4.2) adds two one-time attackers, in the same id order:
## - a mini burns out: within `burnout_m` of the cage (or in a slot) it hits once for core_damage and dies, no Scrap;
## - an enemy with `fuse_s` (the burster) arms when it reaches its slot (F_ARMED, fuse_ticks) and, when the fuse ends,
##   hits once for core_damage and dies with no Scrap; its death blast on the enemies around it follows through
##   DeathHooks. A stun freezes the fuse. Killed before that, it only causes its death blast.
## - a parked standoff enemy with core damage (the spitter) lobs a bolt every attack period instead of hitting: the bolt
##   is a K_BOLT entry of the hazard queue (it survives its shooter, it is hashed and saved with the queue) and it
##   lands `bolt_flight_s` later for the core damage of the moment it was fired, shield first, as a CORE_HIT with no
##   living attacker. HazardSystem drops K_BOLT entries without an effect, so `_land_bolts` applies an entry one tick
##   before the queue removes it and the bolt is queued one tick longer: the damage lands exactly `bolt_flight_s`
##   after the shot. A parked standoff enemy without core damage (the reclaimer, a ward pylon) does nothing here. A
##   standoff boss (the Lance Platform, parked by its script) is an ordinary attacker: its timer and hit are the
##   plain ones below.
## - a body still under the ground (F_EMERGING) does nothing.
## Core damage is multiplied by the act's core_dmg_mult. The attack period is multiplied by the wave modifier and by
## the overclock aura the attacker stands in (NavState.period_mul). A LEECHING elite heals its neighbours on a hit that
## took core HP (EliteSystem.on_core_hit).

const ST_ATTACKING: int = EnemyStore.ST_ATTACKING
const F_MINI: int = EnemyExtState.F_MINI
const F_ARMED: int = EnemyExtState.F_ARMED
const F_FIRED: int = EnemyExtState.F_FIRED
const F_EMERGING: int = EnemyExtState.F_EMERGING
## Radius of a bolt's impact mark on the cage (the hazard queue wants one; it damages nothing but the core).
const BOLT_RADIUS_M: float = 0.6
const UNKNOWN: int = -1


static func step(world: SimWorld) -> void:
	var store: EnemyStore = world.enemies
	var variety: bool = world.content.run != null
	var alive: PackedByteArray = store.alive
	var states: PackedByteArray = store.state
	var stunned: PackedInt32Array = store.stun_ticks
	var due: PackedInt32Array = PackedInt32Array()
	var one_time: PackedInt32Array = PackedInt32Array()  # the entries of `due` that die with their hit
	# variety only: read-only views and per-type tables filled on first use (UNKNOWN until then)
	var flags: PackedInt32Array = world.ext.flags
	var types: PackedByteArray = store.type
	var xs: PackedFloat64Array = store.x
	var zs: PackedFloat64Array = store.z
	var core_x: float = world.content.arena.core_x
	var core_z: float = world.content.arena.core_z
	var reach_sq: PackedFloat64Array = PackedFloat64Array()
	var fuse: PackedInt32Array = PackedInt32Array()
	if variety:
		if not world.hazards.q_due.is_empty():
			_land_bolts(world)
		reach_sq.resize(world.content.enemies.size())
		reach_sq.fill(float(UNKNOWN))
		fuse.resize(world.content.enemies.size())
		fuse.fill(UNKNOWN)
	for i: int in store.high_water:
		if alive[i] == 0 or stunned[i] > 0:
			continue
		var attacking: bool = states[i] == ST_ATTACKING
		if variety:
			var t: int = types[i]
			if (flags[i] & F_MINI) != 0:
				if reach_sq[t] < 0.0:
					reach_sq[t] = _burnout_reach_sq(world, t)
				var dx: float = xs[i] - core_x
				var dz: float = zs[i] - core_z
				if attacking or dx * dx + dz * dz <= reach_sq[t]:
					due.append(i)
					one_time.append(i)
				continue
			if (flags[i] & F_EMERGING) != 0:
				continue
			if attacking and world.nav.t_standoff[t] == 1 and world.nav.t_boss[t] == 0:
				_standoff_tick(world, i, t)
				continue
			if attacking:
				if fuse[t] == UNKNOWN:
					fuse[t] = _fuse_ticks(world, t)
				if fuse[t] > 0:
					if _fuse_tick(world, i, fuse[t]):
						due.append(i)
						one_time.append(i)
					continue
		if not attacking:
			continue
		store.attack_cd[i] -= 1
		if store.attack_cd[i] <= 0:
			due.append(i)
	if due.is_empty():
		return
	_sort_by_id(store, due)
	for i: int in due:
		_hit_core(world, i)
		if one_time.has(i):
			world.kill_enemy(i, DeathHooks.SOURCE_SELF)


## Damages the core by `amount`, shield first (SHIELD_CHANGED); the remainder goes through set_core_hp unless the core
## is debug-invulnerable. Pushes CORE_HIT(enemy id, type, hp damage actually dealt, absorbed by the shield) and
## returns the hp damage. `enemy_id` 0 = no living attacker (a death blast); `type_index` -1 = none.
static func damage_core(world: SimWorld, amount: float, enemy_id: int, type_index: int) -> float:
	var remainder: float = amount
	var absorbed: float = 0.0
	if world.shield_hp > 0.0:
		absorbed = minf(world.shield_hp, remainder)
		world.shield_hp -= absorbed
		remainder -= absorbed
		var shield_max: float = world.content.abilities[Ids.AB_SHIELD].absorb
		world.events.push(SimEventKind.Id.SHIELD_CHANGED, 0, 0, world.shield_hp, shield_max)
		world.stats.damage_absorbed += absorbed
	var hp_damage: float = 0.0
	if remainder > 0.0 and not world.config.debug_invulnerable_core:
		var before: float = world.core_hp
		world.set_core_hp(before - remainder)
		hp_damage = before - world.core_hp
		world.stats.core_damage_taken += hp_damage
		if type_index >= 0 and type_index < world.stats.core_damage_by_type.size():
			world.stats.core_damage_by_type[type_index] += hp_damage
	world.combat.core_hits += 1
	world.events.push(SimEventKind.Id.CORE_HIT, enemy_id, type_index, hp_damage, absorbed)
	return hp_damage


## The core damage of one hit of enemy type `def` now: the type's value x the act tier.
static func core_damage_of(world: SimWorld, def: EnemyDef) -> float:
	return def.core_damage * core_mult(world)


## The act tier of core damage (ActDef.core_dmg_mult); 1 in the legacy content.
static func core_mult(world: SimWorld) -> float:
	var run: RunDef = world.content.run
	if run == null:
		return 1.0
	var act: ActDef = run.act(world.phase_state.act)
	return act.core_dmg_mult if act != null else 1.0


## One hit of the enemy at store index `index`; its attack timer restarts.
static func _hit_core(world: SimWorld, index: int) -> void:
	var store: EnemyStore = world.enemies
	var def: EnemyDef = world.content.enemies[store.type[index]]
	var shield_before: float = world.shield_hp
	var hp_damage: float = damage_core(world, core_damage_of(world, def), store.id[index], store.type[index])
	if world.content.run == null:
		store.attack_cd[index] = def.attack_period_ticks
		return
	store.attack_cd[index] = period_of(world, index, def)
	CoreHooks.on_core_hit(world, index, hp_damage, shield_before - world.shield_hp)
	EliteSystem.on_core_hit(world, index, hp_damage)


## The attack period of the enemy at `index` now, in ticks: the type's period x the wave modifier x the overclock aura.
static func period_of(world: SimWorld, index: int, def: EnemyDef) -> int:
	var scaled: float = float(def.attack_period_ticks) * world.mods.enemy_attack_period_mul * world.nav.period_mul[index]
	return maxi(1, roundi(scaled))


## One tick of a parked standoff enemy: a type with core damage that is no boss fires a bolt when its timer runs out.
static func _standoff_tick(world: SimWorld, index: int, type_index: int) -> void:
	var def: EnemyDef = world.content.enemies[type_index]
	if def.core_damage <= 0.0:
		return
	var store: EnemyStore = world.enemies
	store.attack_cd[index] -= 1
	if store.attack_cd[index] > 0:
		return
	store.attack_cd[index] = period_of(world, index, def)
	world.ext.flags[index] |= F_FIRED
	var flight: int = maxi(1, Formulas.ticks(def.beh(&"bolt_flight_s")))
	var arena: ArenaDef = world.content.arena
	var dx: float = store.x[index] - arena.core_x
	var dz: float = store.z[index] - arena.core_z
	var d: float = maxf(0.001, sqrt(dx * dx + dz * dz))
	var hit_x: float = arena.core_x + dx / d * arena.core_radius
	var hit_z: float = arena.core_z + dz / d * arena.core_radius
	var seq: int = HazardSystem.queue_blast(
		world, world.tick + flight + 1, HazardState.K_BOLT, hit_x, hit_z, BOLT_RADIUS_M, 0.0, 1.0, 0, DeathHooks.SOURCE_SELF,
		core_damage_of(world, def), type_index
	)
	if seq > 0:
		world.events.push(SimEventKind.Id.DELAYED_HIT_LAUNCHED, HazardState.K_BOLT, flight, store.x[index], store.z[index])


## The bolts that land this tick (see the header): every K_BOLT entry the hazard queue will remove on the next tick,
## in queue order.
static func _land_bolts(world: SimWorld) -> void:
	var h: HazardState = world.hazards
	var next_tick: int = world.tick + 1
	for q: int in h.q_due.size():
		if h.q_due[q] > next_tick:
			break
		if h.q_due[q] == next_tick and h.q_kind[q] == HazardState.K_BOLT and h.q_core[q] > 0.0:
			world.events.push(SimEventKind.Id.AREA_BLAST, HazardState.K_BOLT, roundi(h.q_radius[q] * 100.0), h.q_x[q], h.q_z[q])
			damage_core(world, h.q_core[q], 0, h.q_type[q])


## Squared distance from the core centre at which a mini of type `type_index` burns out (cage radius + burnout_m).
static func _burnout_reach_sq(world: SimWorld, type_index: int) -> float:
	var reach: float = world.content.arena.core_radius + world.content.enemies[type_index].beh(&"burnout_m", 0.6)
	return reach * reach


## The fuse of enemy type `type_index` in ticks, 0 = the type has none.
static func _fuse_ticks(world: SimWorld, type_index: int) -> int:
	var seconds: float = world.content.enemies[type_index].beh(&"fuse_s")
	return maxi(1, Formulas.ticks(seconds)) if seconds > 0.0 else 0


## One tick of a fused enemy in its slot: it arms on the first, then the fuse runs. True when it detonates now.
static func _fuse_tick(world: SimWorld, index: int, fuse_ticks: int) -> bool:
	var ext: EnemyExtState = world.ext
	if (ext.flags[index] & F_ARMED) == 0:
		ext.flags[index] |= F_ARMED
		ext.fuse_ticks[index] = fuse_ticks
		return false
	ext.fuse_ticks[index] -= 1
	return ext.fuse_ticks[index] <= 0


## Insertion sort of store indices by ascending enemy id (the list is tiny: hits due this tick).
static func _sort_by_id(store: EnemyStore, indices: PackedInt32Array) -> void:
	for a: int in range(1, indices.size()):
		var moving: int = indices[a]
		var b: int = a - 1
		while b >= 0 and store.id[indices[b]] > store.id[moving]:
			indices[b + 1] = indices[b]
			b -= 1
		indices[b + 1] = moving
