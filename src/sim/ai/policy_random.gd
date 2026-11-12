class_name PolicyRandom
extends RefCounted
## Bot policy `random` (VARIETY_SPEC 14.1, CONTENT 13): uniform choices from the bot's OWN generator (seeded from
## hash(seed, "bot"), never a sim stream); each ready ability with 2% chance per second. Every choice is drawn when it
## is answered and the ability roll happens once per second of ticks, so neither the number of calls nor thinking time
## changes the sequence of draws.
## Deterministic; talks to the sim only through `bot.send`; never reads a sim stream.

const ABILITY_CHANCE: float = 0.02
const ROLL_PERIOD: int = 60  ## one roll per second of ticks


## Submits this policy's commands for the next tick. PolicyBot.act dispatches here.
static func act(world: SimWorld, bot: PolicyBot) -> void:
	if PolicyAnswers.waiting(world):
		_answer(world, bot)
		return
	if world.tick % ROLL_PERIOD != 0 or world.tick == bot.last_roll_tick:
		return
	bot.last_roll_tick = world.tick
	var rng: RandomNumberGenerator = bot.bot_rng(world)
	for ability_index: int in world.content.abilities.size():
		if world.ability_block_reason(ability_index) == Reason.Id.OK and rng.randf() < ABILITY_CHANCE:
			bot.send(world, SimCommand.Kind.ABILITY, ability_index)


static func _answer(world: SimWorld, bot: PolicyBot) -> void:
	var rng: RandomNumberGenerator = bot.bot_rng(world)
	match world.phase_state.awaiting:
		PhaseState.Await.SALVAGE:
			var args: Array[int] = PolicyLoadout.legal_args(world)
			bot.send(world, SimCommand.Kind.SALVAGE, args[rng.randi_range(0, args.size() - 1)])
		PhaseState.Await.DRAFT:
			var slots: Array[int] = PolicyAnswers.open_slots(world)
			if slots.is_empty():
				bot.send(world, SimCommand.Kind.SKIP_DRAFT, 0)
			else:
				bot.send(world, SimCommand.Kind.PICK_DIRECTIVE, slots[rng.randi_range(0, slots.size() - 1)])
		PhaseState.Await.ROUTE:
			var options: int = maxi(1, PolicyAnswers.route_options(world).size())
			bot.send(world, SimCommand.Kind.PICK_ROUTE, rng.randi_range(0, options - 1))
		_:
			bot.send(world, SimCommand.Kind.SKIP_INTERMISSION, 0)
