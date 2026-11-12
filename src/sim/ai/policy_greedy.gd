class_name PolicyGreedy
extends RefCounted
## Bot policy `greedy` (VARIETY_SPEC 14.1, CONTENT 13): lowest rarity, ties leftmost; never rerolls; option A; takes
## every crate into the emptiest slot (a duplicate of a carried weapon levels it up instead) and never swaps. In
## combat it plays exactly as the original GREEDY bot did: it buys the cheapest upgrade the shop allows, and fires EMP
## at 12 attackers, Shield when the core is hit and Overdrive with the boss in range (a closed shop buys nothing).
## Deterministic; talks to the sim only through `bot.send`; never reads a sim stream.


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(world: SimWorld, bot: PolicyBot) -> void:
	if PolicyAnswers.answer(world, bot, PolicyAnswers.Style.GREEDY):
		return
	bot.play_legacy(world)
