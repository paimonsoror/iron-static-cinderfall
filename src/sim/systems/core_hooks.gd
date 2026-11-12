class_name CoreHooks
extends RefCounted
## The core-side hook points of directives (CONTENT 3.3, 3.4, 3.5): one function per hook. The callers are the systems
## that own the moment (CoreAttackSystem, AbilitySystem, PhaseSystem); each call point is added by the owner of that
## system in its own wave.
# TODO(V4-C)


## reactive_plating, ember_vent, the_tally: after an enemy hit on the core was applied.
static func on_core_hit(_world: SimWorld, _enemy_index: int, _hp_damage: float, _absorbed: float) -> void:
	pass


## amber_surge: the core went from `before` to `after`.
static func on_core_changed(_world: SimWorld, _before: float, _after: float) -> void:
	pass


## dead_mans_switch: called when core_hp <= 0. True = the run is lost; false = the hook saved the core.
static func allow_defeat(_world: SimWorld) -> bool:
	return true


## field_weld, compound_interest, borrowed_time, route rewards: before the first await of the intermission.
static func on_wave_cleared(_world: SimWorld) -> void:
	pass


## cascade, overclocked_core.
static func on_ability(_world: SimWorld, _ability_index: int) -> void:
	pass


## emp_overload.
static func on_emp(_world: SimWorld) -> void:
	pass


## shield_burst: the shield ended or broke.
static func on_shield_end(_world: SimWorld) -> void:
	pass
