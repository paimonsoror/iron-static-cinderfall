class_name PolicyRisk
extends RefCounted
## Bot policy `risk` (VARIETY_SPEC 14.1, CONTENT 13): takes every corrupted directive offered, else as balanced; always the hot route.
## Deterministic; talks to the sim only through `world.submit` with ids from `bot`; never reads a sim stream.
# TODO(V4-T)


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(_world: SimWorld, _bot: PolicyBot) -> void:
	pass
