class_name PolicyGreedy
extends RefCounted
## Bot policy `greedy` (VARIETY_SPEC 14.1, CONTENT 13): lowest rarity, ties leftmost; never rerolls; option A; takes every crate into the emptiest slot and never
## swaps; abilities as PolicyBot.GREEDY does today.
## Deterministic; talks to the sim only through `world.submit` with ids from `bot`; never reads a sim stream.
# TODO(V2-H)


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(_world: SimWorld, _bot: PolicyBot) -> void:
	pass
