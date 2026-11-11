class_name CoreAttackSystem
extends RefCounted
## Enemies standing in their attack slot hit the core, shield first (ARCH 6.6; GDD 6).
##
## Every alive ST_ATTACKING enemy that is not stunned counts attack_cd down by one; at 0 it hits for
## core_damage and the timer restarts at attack_period_ticks. A stunned enemy's timer is frozen. Hits that
## land on the same tick are applied in ascending enemy id order, so the shield is spent deterministically.


static func step(world: SimWorld) -> void:
	var store: EnemyStore = world.enemies
	var due: PackedInt32Array = PackedInt32Array()
	for i: int in store.high_water:
		if store.alive[i] == 0 or store.state[i] != EnemyStore.ST_ATTACKING or store.stun_ticks[i] > 0:
			continue
		store.attack_cd[i] -= 1
		if store.attack_cd[i] <= 0:
			due.append(i)
	if due.is_empty():
		return
	_sort_by_id(store, due)
	for i: int in due:
		_hit_core(world, i)


## Shield absorbs first (SHIELD_CHANGED), the remainder goes through set_core_hp unless the core is
## debug-invulnerable. Pushes CORE_HIT(enemy id, type, hp damage actually dealt, absorbed by the shield).
static func _hit_core(world: SimWorld, index: int) -> void:
	var store: EnemyStore = world.enemies
	var def: EnemyDef = world.content.enemies[store.type[index]]
	var remainder: float = def.core_damage
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
	world.combat.core_hits += 1
	world.events.push(SimEventKind.Id.CORE_HIT, store.id[index], store.type[index], hp_damage, absorbed)
	store.attack_cd[index] = def.attack_period_ticks


## Insertion sort of store indices by ascending enemy id (the list is tiny: hits due this tick).
static func _sort_by_id(store: EnemyStore, indices: PackedInt32Array) -> void:
	for a: int in range(1, indices.size()):
		var moving: int = indices[a]
		var b: int = a - 1
		while b >= 0 and store.id[indices[b]] > store.id[moving]:
			indices[b + 1] = indices[b]
			b -= 1
		indices[b + 1] = moving
