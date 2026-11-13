class_name PolicyHoarder
extends RefCounted
## Bot policy `hoarder` (VARIETY_SPEC 14.1, CONTENT 13): weapon directives first, and a reroll when the offer shows none
## while it holds 200 Scrap (below that it takes the best-scoring card: it saves its Scrap for the weapon rerolls); the route with a crate (`rw_crate`), else the hot one; it keeps the two highest weapon
## tiers and swaps to the higher tier whenever that weapon is ready (PolicyHoard); abilities as `greedy`.
## Deterministic; talks to the sim only through `bot.send`; never reads a sim stream.

const FAVOURED: Array[int] = [DirectiveDef.Category.WEAPON]
const CRATE_REWARD: StringName = &"rw_crate"


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(world: SimWorld, bot: PolicyBot) -> void:
	if PolicyAnswers.waiting(world):
		answer(world, bot)
		return
	PolicyHoard.act_swap(world, bot)
	bot.play_legacy(world)


## One command for the current await.
static func answer(world: SimWorld, bot: PolicyBot) -> void:
	match world.phase_state.awaiting:
		PhaseState.Await.SALVAGE:
			bot.send(world, SimCommand.Kind.SALVAGE, PolicyHoard.salvage_arg(world))
		PhaseState.Await.DRAFT:
			PolicyDraft.answer_favouring(world, bot, FAVOURED, PolicyDraft.HOARDER_REROLL_SCRAP, false)
		PhaseState.Await.ROUTE:
			bot.send(world, SimCommand.Kind.PICK_ROUTE, route(world))
		_:
			bot.send(world, SimCommand.Kind.SKIP_INTERMISSION, 0)


## The option with a crate, else the hot option (option A when neither exists).
static func route(world: SimWorld) -> int:
	var crate: int = PolicyTaste.route_with_reward(world, CRATE_REWARD)
	return crate if crate >= 0 else PolicyTaste.route_hot(world)
