class_name PolicyAnswers
extends RefCounted
## How the simple bots answer the intermission choices (VARIETY_SPEC 2.5, CONTENT 13), and the net under every bot:
## whatever a policy decides, a world that waits for a choice gets an answer on the next call (the tick does not
## advance while it waits, so a bot that stayed silent would hang the run). Pure reads of the world plus commands
## through `bot.send`; no random stream.

## The two baseline styles: `none` skips and scraps, `greedy` takes the cheapest draft card and the emptiest slot.
enum Style { NONE, GREEDY }


## True when the world waits for a choice.
static func waiting(world: SimWorld) -> bool:
	return world.phase_state.awaiting != PhaseState.Await.NONE


## Submits one command for the current await in the given style. False when nothing awaits.
static func answer(world: SimWorld, bot: PolicyBot, style: int) -> bool:
	match world.phase_state.awaiting:
		PhaseState.Await.SALVAGE:
			bot.send(world, SimCommand.Kind.SALVAGE, _salvage_arg(world, style))
		PhaseState.Await.DRAFT:
			var slot: int = lowest_rarity_slot(world) if style == Style.GREEDY else -1
			if slot >= 0:
				bot.send(world, SimCommand.Kind.PICK_DIRECTIVE, slot)
			else:
				bot.send(world, SimCommand.Kind.SKIP_DRAFT, 0)
		PhaseState.Await.ROUTE:
			bot.send(world, SimCommand.Kind.PICK_ROUTE, 0)  # option A, the standard route
		PhaseState.Await.BOSS_BRIEF:
			bot.send(world, SimCommand.Kind.SKIP_INTERMISSION, 0)  # the CONTINUE button
		_:
			return false
	return true


## The net: a policy that left a choice unanswered gets the `none` answer for it.
static func ensure_answered(world: SimWorld, bot: PolicyBot) -> void:
	if waiting(world) and world.command_queue.is_empty():
		answer(world, bot, Style.NONE)


## Slots of the open draft that still hold a directive, left to right.
static func open_slots(world: SimWorld) -> Array[int]:
	var out: Array[int] = []
	var offer: PackedInt32Array = world.draft.offer
	for slot: int in offer.size():
		if offer[slot] >= 0 and offer[slot] < world.content.directives.size():
			out.append(slot)
	return out


## The open slot with the lowest rarity, ties to the leftmost; -1 when the offer is empty.
static func lowest_rarity_slot(world: SimWorld) -> int:
	var best: int = -1
	var best_rarity: int = 0
	for slot: int in open_slots(world):
		var rarity: int = world.content.directives[world.draft.offer[slot]].rarity
		if best < 0 or rarity < best_rarity:
			best = slot
			best_rarity = rarity
	return best


## Options of the route step: the plan of the wave that starts next (1 when it is unknown).
static func route_options(world: SimWorld) -> Array[RouteOption]:
	var out: Array[RouteOption] = []
	if world.plan == null:
		return out
	var planned: PlannedWave = world.plan.wave(PolicySenses.next_wave(world))
	if planned != null:
		out.append_array(planned.options)
	return out


static func _salvage_arg(world: SimWorld, style: int) -> int:
	if style == Style.GREEDY:
		return PolicyLoadout.greedy_salvage_arg(world)
	return PolicyLoadout.SCRAP_ARG
