class_name PolicyHoarder
extends RefCounted
## Bot policy `hoarder` (VARIETY_SPEC 14.1, CONTENT 13): weapon directives first; the option with a crate, else hot; keeps the two highest weapon tiers.
## Deterministic; talks to the sim only through `world.submit` with ids from `bot`; never reads a sim stream.
# TODO(V4-T)


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(_world: SimWorld, _bot: PolicyBot) -> void:
	pass
