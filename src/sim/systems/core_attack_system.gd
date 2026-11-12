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
## Core damage is multiplied by the act's core_dmg_mult.

const ST_ATTACKING: int = EnemyStore.ST_ATTACKING
const F_MINI: int = EnemyExtState.F_MINI
const F_ARMED: int = EnemyExtState.F_ARMED
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
	store.attack_cd[index] = maxi(1, roundi(float(def.attack_period_ticks) * world.mods.enemy_attack_period_mul))
	CoreHooks.on_core_hit(world, index, hp_damage, shield_before - world.shield_hp)


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
