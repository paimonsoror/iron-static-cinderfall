class_name PolicyNone
extends RefCounted
## Bot policy `none` (VARIETY_SPEC 14.1, CONTENT 13): the player who does nothing. It never buys, never uses an
## ability, never swaps; at the intermission it skips the draft, takes route option A and scraps every crate. It still
## answers each choice, because the sim holds its tick until a choice is made.
## Deterministic; talks to the sim only through `bot.send`; never reads a sim stream.


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(world: SimWorld, bot: PolicyBot) -> void:
	PolicyAnswers.answer(world, bot, PolicyAnswers.Style.NONE)
