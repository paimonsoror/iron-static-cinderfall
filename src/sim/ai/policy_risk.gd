class_name PolicyRisk
extends RefCounted
## Bot policy `risk` (VARIETY_SPEC 14.1, CONTENT 13): takes every corrupted directive offered, else drafts as
## `balanced`; always the hot route; crates, swaps, abilities and calls as `balanced`.
## Deterministic; talks to the sim only through `bot.send`; never reads a sim stream.


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(world: SimWorld, bot: PolicyBot) -> void:
	if PolicyAnswers.waiting(world):
		answer(world, bot)
		return
	PolicyLoadout.act_swap(world, bot)
	PolicyAbilities.act(world, bot)


## One command for the current await.
static func answer(world: SimWorld, bot: PolicyBot) -> void:
	match world.phase_state.awaiting:
		PhaseState.Await.DRAFT:
			PolicyDraft.answer_risk(world, bot)
		PhaseState.Await.ROUTE:
			bot.send(world, SimCommand.Kind.PICK_ROUTE, PolicyTaste.route_hot(world))
		_:
			PolicyBalanced.answer(world, bot)
