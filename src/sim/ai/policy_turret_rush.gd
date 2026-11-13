class_name PolicyTurretRush
extends RefCounted
## Bot policy `turret_rush` (VARIETY_SPEC 14.1, CONTENT 13): turret directives first, then core directives; the
## standard route option; crates and abilities as `greedy` (the emptiest slot, never a swap, EMP at 12 attackers,
## Shield when hit, Overdrive on a boss in range).
## Deterministic; talks to the sim only through `bot.send`; never reads a sim stream.

const FAVOURED: Array[int] = [DirectiveDef.Category.TURRET, DirectiveDef.Category.CORE]


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(world: SimWorld, bot: PolicyBot) -> void:
	if PolicyAnswers.waiting(world):
		answer(world, bot)
		return
	bot.play_legacy(world)


## One command for the current await.
static func answer(world: SimWorld, bot: PolicyBot) -> void:
	match world.phase_state.awaiting:
		PhaseState.Await.SALVAGE:
			bot.send(world, SimCommand.Kind.SALVAGE, PolicyLoadout.greedy_salvage_arg(world))
		PhaseState.Await.DRAFT:
			PolicyDraft.answer_favouring(world, bot, FAVOURED)
		PhaseState.Await.ROUTE:
			bot.send(world, SimCommand.Kind.PICK_ROUTE, PolicyTaste.route_standard(world))
		_:
			bot.send(world, SimCommand.Kind.SKIP_INTERMISSION, 0)
