class_name DamageResolver
extends RefCounted
## Applies hits (ARCH 6.5, 6.6). The only writer of enemies.hp.


## Applies Formulas with the current armor_piercing level and debug_damage_mult; clamps hp at 0; pushes
## ENEMY_DAMAGED(enemy id, source, damage dealt, hp after); calls world.kill_enemy at hp <= 0 (exactly once:
## a second hit on a dead or freed slot does nothing). Returns the damage dealt, which an overkill hit
## limits to the hp the enemy had left. debug_damage_mult scales the final per-hit damage (after armor).
static func hit(world: SimWorld, enemy_index: int, base_damage: float, damage_level: int, source: int) -> float:
	var store: EnemyStore = world.enemies
	if enemy_index < 0 or enemy_index >= store.capacity or store.alive[enemy_index] == 0:
		return 0.0
	var content: ContentSet = world.content
	var def: EnemyDef = content.enemies[store.type[enemy_index]]
	var piercing: UpgradeDef = content.upgrades[Ids.UP_ARMOR_PIERCING]
	var damage_up: UpgradeDef = content.upgrades[Ids.UP_DAMAGE]
	var eff_armor: float = Formulas.effective_armor(
		def.armor, world.upgrade_levels[Ids.UP_ARMOR_PIERCING], piercing.per_level, piercing.cap
	)
	var raw: float = Formulas.hit_damage(base_damage, damage_level, damage_up.per_level, eff_armor)
	raw *= world.config.debug_damage_mult
	var hp_before: float = maxf(0.0, store.hp[enemy_index])
	var dealt: float = minf(raw, hp_before)
	var hp_after: float = hp_before - dealt
	store.hp[enemy_index] = hp_after
	world.events.push(SimEventKind.Id.ENEMY_DAMAGED, store.id[enemy_index], source, dealt, hp_after)
	var tallied: bool = source >= 0 and source < CombatState.SOURCES
	if tallied:
		world.combat.damage_by_source[source] += dealt
	if hp_after <= 0.0:
		if tallied:
			world.combat.kills_by_source[source] += 1
		world.kill_enemy(enemy_index, source)
	return dealt
