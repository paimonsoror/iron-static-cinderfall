class_name DamageResolver
extends RefCounted
## Applies hits. TODO(W1-B).

@warning_ignore_start("unused_parameter")

## Applies Formulas with the current armor_piercing level and debug_damage_mult; clamps hp at 0; pushes
## ENEMY_DAMAGED; calls world.kill_enemy at hp <= 0; returns damage dealt.
static func hit(world: SimWorld, enemy_index: int, base_damage: float, damage_level: int, source: int) -> float:
	# TODO(W1-B)
	return 0.0
