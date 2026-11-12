class_name ModSystem
extends RefCounted
## The `ops[]` interpreter (VARIETY_SPEC 13.1, 13.2). The only writer of ModState; it also feeds the legacy level
## fields (`world.upgrade_levels[UP_DAMAGE | UP_FIRE_RATE | UP_ARMOR_PIERCING]`) from the three stat directives, so
## Formulas and its golden values stay the single damage path. Core maximum changes go through SimWorld.set_core_max.
# TODO(V2-B): the stub changes nothing.


## Applies the kit of the run (SimConfig.kit_index). Called once by SimWorld._init.
static func init_world(_world: SimWorld) -> void:
	pass


## Rebuilds ModState from the kit, the held directives (DraftState.stacks) and the wave modifier.
static func recompute(_world: SimWorld) -> void:
	pass


## Applies `ops` `stacks` times onto ModState (ADD, MUL, FLAG). GRANT ops are one-time effects: see `grant`.
static func apply_ops(_world: SimWorld, _ops: Array[OpDef], _stacks: int) -> void:
	pass


## The one-time GRANT ops of `ops` (scrap, core repair, charges, weapons, ...), in order.
static func grant(_world: SimWorld, _ops: Array[OpDef]) -> void:
	pass


## Sets the modifier of the wave that starts (-1 = none) and recomputes.
static func set_wave_modifier(_world: SimWorld, _modifier_index: int) -> void:
	pass
