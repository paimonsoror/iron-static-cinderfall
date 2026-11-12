class_name PolicyBalanced
extends RefCounted
## Bot policy `balanced` (VARIETY_SPEC 14.1, CONTENT 13): the reference competent player: scores each directive (tag synergy, gaps, rarity, corrupted risk),
## rerolls weak offers, takes hot routes on a healthy core, swaps to the area weapon on a crowd.
## Deterministic; talks to the sim only through `world.submit` with ids from `bot`; never reads a sim stream.
# TODO(V2-H)


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(_world: SimWorld, _bot: PolicyBot) -> void:
	pass
