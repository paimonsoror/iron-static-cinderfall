class_name PolicyRandom
extends RefCounted
## Bot policy `random` (VARIETY_SPEC 14.1, CONTENT 13): uniform choices from the bot's OWN generator (seeded from hash(seed, "bot")), never a sim stream; each ready
## ability with 2% chance per second.
## Deterministic; talks to the sim only through `world.submit` with ids from `bot`; never reads a sim stream.
# TODO(V2-H)


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(_world: SimWorld, _bot: PolicyBot) -> void:
	pass
