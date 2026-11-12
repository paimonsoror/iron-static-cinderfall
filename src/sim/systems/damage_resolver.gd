class_name DamageResolver
extends RefCounted
## Applies hits (ARCH 6.5, 6.6). The only writer of enemies.hp (heals included).
##
## Damage order (VARIETY_SPEC 3.3): weapon damage x weapon level x the damage-level formula x conditional multipliers
## (`warden_amount`), then - effective armor, x reductions, x debug_damage_mult (`hit_ex`). The legacy `hit` is the same
## path with no flags, so the golden values of ARCH 6.5 hold for both.

## Flags of `hit_ex` (VARIETY_SPEC 13.2).
const F_IGNORE_ARMOR: int = 1
const F_HALF_ARMOR: int = 2
const F_AREA: int = 4  ## a blast, pool or chain: never triggers on-hit hooks again
const F_NO_WARD: int = 8  ## passes wards and shieldbearer protection
const F_BURN: int = 16  ## damage over time: no armor and no 1-damage floor
const F_BOSS_HALF: int = 32  ## a boss takes half (the Deadfall Strike and the freight car, CONTENT 6)


## Applies Formulas with the current armor_piercing level and debug_damage_mult; clamps hp at 0; pushes
## ENEMY_DAMAGED(enemy id, source, damage dealt, hp after); calls world.kill_enemy at hp <= 0 (exactly once:
## a second hit on a dead or freed slot does nothing). Returns the damage dealt, which an overkill hit
## limits to the hp the enemy had left. debug_damage_mult scales the final per-hit damage (after armor).
static func hit(world: SimWorld, enemy_index: int, base_damage: float, damage_level: int, source: int) -> float:
	var damage_up: UpgradeDef = world.content.upgrades[Ids.UP_DAMAGE]
	return hit_ex(world, enemy_index, base_damage * (1.0 + damage_up.per_level * float(damage_level)), 0, source)


## The variety damage path (VARIETY_SPEC 3.3 damage order): `amount` is the damage before armor, with the weapon level
## and conditional multipliers already applied by the caller; this applies effective armor (reduced by `flags` and
## shred), the boss rule of F_BOSS_HALF and debug_damage_mult, tallies by `source` (DamageSource.Id; a value outside
## the enum is not tallied), pushes ENEMY_DAMAGED and kills at 0 hp. Returns the damage dealt.
# TODO(V4-N): wards and the shieldbearer reduction go here (F_NO_WARD skips them).
static func hit_ex(world: SimWorld, enemy_index: int, amount: float, flags: int, source: int) -> float:
	var store: EnemyStore = world.enemies
	if enemy_index < 0 or enemy_index >= store.capacity or store.alive[enemy_index] == 0:
		return 0.0
	var def: EnemyDef = world.content.enemies[store.type[enemy_index]]
	var raw: float = amount
	if (flags & F_BOSS_HALF) != 0 and def.is_boss:
		raw *= 0.5
	if (flags & F_BURN) == 0:
		raw = maxf(1.0, raw - effective_armor(world, enemy_index, flags))
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


## The armor a hit with `flags` meets: the type's armor plus the wave modifier, minus shred, through the unchanged
## Formulas.effective_armor with the armor_piercing level; 0 with F_IGNORE_ARMOR, half with F_HALF_ARMOR.
static func effective_armor(world: SimWorld, enemy_index: int, flags: int) -> float:
	if (flags & F_IGNORE_ARMOR) != 0:
		return 0.0
	var content: ContentSet = world.content
	var armor: float = content.enemies[world.enemies.type[enemy_index]].armor
	if content.run != null:
		armor = maxf(0.0, armor + world.mods.enemy_armor_add - float(world.ext.shred_milli[enemy_index]) / 1000.0)
	var piercing: UpgradeDef = content.upgrades[Ids.UP_ARMOR_PIERCING]
	var eff: float = Formulas.effective_armor(
		armor, world.upgrade_levels[Ids.UP_ARMOR_PIERCING], piercing.per_level, piercing.cap
	)
	if (flags & F_HALF_ARMOR) != 0:
		eff *= 0.5
	return eff


## Damage before armor of one Warden hit of `def` at weapon level `level` (1..3) on `enemy_index`: weapon damage x
## level_mult x (1 + per_level x damage level) x w_dmg_mul x the conditional multipliers (full HP, low HP, stunned).
static func warden_amount(world: SimWorld, enemy_index: int, def: WeaponDef, level: int) -> float:
	var store: EnemyStore = world.enemies
	var mods: ModState = world.mods
	var damage_up: UpgradeDef = world.content.upgrades[Ids.UP_DAMAGE]
	var amount: float = def.damage * float(def.level_mult[clampi(level, 1, def.level_mult.size()) - 1])
	amount *= 1.0 + damage_up.per_level * float(world.upgrade_levels[Ids.UP_DAMAGE])
	amount *= mods.w_dmg_mul
	var hp: float = store.hp[enemy_index]
	var max_hp: float = store.max_hp[enemy_index]
	if hp >= max_hp:
		amount *= mods.w_full_hp_mul
	elif max_hp > 0.0 and hp / max_hp < mods.w_low_hp_threshold:
		amount *= mods.w_low_hp_mul
	if store.stun_ticks[enemy_index] > 0:
		amount *= def.stunned_mult * mods.stunned_dmg_mul
	return amount


## The flags a weapon's `armor_ignore` stands for: all of the armor, half of it, or none.
static func weapon_flags(def: WeaponDef) -> int:
	if def.armor_ignore >= 1.0:
		return F_IGNORE_ARMOR
	if def.armor_ignore > 0.0:
		return F_HALF_ARMOR
	return 0


## One Warden hit of `def` on `enemy_index`, x `scale` (pierce or chain falloff). `flags` are added to the weapon's own.
## A direct hit (no F_AREA) runs the shot hooks: on_warden_hit on a survivor (and the burn of incendiary_tips), and
## on_warden_kill on a kill. Returns the damage dealt.
static func warden_hit(
	world: SimWorld, enemy_index: int, def: WeaponDef, level: int, scale: float, flags: int, source: int
) -> float:
	var store: EnemyStore = world.enemies
	if enemy_index < 0 or enemy_index >= store.capacity or store.alive[enemy_index] == 0:
		return 0.0
	var x: float = store.x[enemy_index]
	var z: float = store.z[enemy_index]
	var amount: float = warden_amount(world, enemy_index, def, level) * scale
	var dealt: float = hit_ex(world, enemy_index, amount, flags | weapon_flags(def), source)
	if (flags & F_AREA) != 0:
		return dealt
	if store.alive[enemy_index] == 1:
		ShotHooks.on_warden_hit(world, enemy_index, dealt)
		StatusSystem.ignite(world, enemy_index)
	else:
		ShotHooks.on_warden_kill(world, x, z)
	return dealt


## Restores up to `amount` hp (never above max_hp); pushes ENEMY_HEALED. Returns the hp restored.
# TODO(V4-N): the stub heals nothing.
static func heal(_world: SimWorld, _enemy_index: int, _amount: float) -> float:
	return 0.0
