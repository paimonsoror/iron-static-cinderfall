class_name ShotHooks
extends RefCounted
## The shot-side hook points of directives (CONTENT 3.1, 3.2): one function per hook, called by ArsenalSystem, the
## fire files and TurretSystem.
# TODO(V2-C): on_warden_hit (incendiary_tips). TODO(V4-W): the rest.


## shock_rounds, the pistol level-3 perk.
static func on_warden_shot(_world: SimWorld, _slot: int, _target_index: int) -> void:
	pass


## incendiary_tips: `dealt` damage was applied to a living enemy.
static func on_warden_hit(world: SimWorld, target_index: int, _dealt: float) -> void:
	StatusSystem.ignite(world, target_index)


## ricochet, kill_chain, unstable_munitions: the Warden killed an enemy at (x, z).
static func on_warden_kill(_world: SimWorld, _x: float, _z: float) -> void:
	pass


## arc_pylons, mine_layer.
static func on_turret_shot(_world: SimWorld, _pad: int, _target_index: int) -> void:
	pass


## flak_heads.
static func on_turret_hit(_world: SimWorld, _pad: int, _target_index: int, _dealt: float) -> void:
	pass
