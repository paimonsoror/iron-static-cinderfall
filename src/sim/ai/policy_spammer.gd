class_name PolicySpammer
extends RefCounted
## Bot policy `spammer` (VARIETY_SPEC 14.1, CONTENT 13): ability directives first; every ability, Deadfall and Vent the tick they are legal.
## Deterministic; talks to the sim only through `world.submit` with ids from `bot`; never reads a sim stream.
# TODO(V4-T)


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(_world: SimWorld, _bot: PolicyBot) -> void:
	pass
