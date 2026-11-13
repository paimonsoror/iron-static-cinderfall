class_name PolicySpammer
extends RefCounted
## Bot policy `spammer` (VARIETY_SPEC 14.1, CONTENT 13): ability directives first; option A; crates as `greedy` (the
## emptiest slot, never a swap); every ability the tick it is ready, and every player-called event (Deadfall, Vent,
## whatever the data adds) the tick the sim allows the call.
## Deterministic; talks to the sim only through `bot.send`; never reads a sim stream.

const FAVOURED: Array[int] = [DirectiveDef.Category.ABILITY]


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(world: SimWorld, bot: PolicyBot) -> void:
	if PolicyAnswers.waiting(world):
		answer(world, bot)
		return
	if not GameState.is_combat(world.phase):
		return
	for ability_index: int in world.content.abilities.size():
		if world.ability_block_reason(ability_index) == Reason.Id.OK:
			bot.send(world, SimCommand.Kind.ABILITY, ability_index)
	for def: EventDef in world.content.events:
		if def.who == EventDef.Who.PLAYER and EventSystem.block_reason(world, def.index) == Reason.Id.OK:
			bot.send(world, SimCommand.Kind.CALL_EVENT, def.index)


## One command for the current await.
static func answer(world: SimWorld, bot: PolicyBot) -> void:
	match world.phase_state.awaiting:
		PhaseState.Await.SALVAGE:
			bot.send(world, SimCommand.Kind.SALVAGE, PolicyLoadout.greedy_salvage_arg(world))
		PhaseState.Await.DRAFT:
			PolicyDraft.answer_favouring(world, bot, FAVOURED)
		PhaseState.Await.ROUTE:
			bot.send(world, SimCommand.Kind.PICK_ROUTE, 0)
		_:
			bot.send(world, SimCommand.Kind.SKIP_INTERMISSION, 0)
