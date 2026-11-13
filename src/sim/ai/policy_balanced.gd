class_name PolicyBalanced
extends RefCounted
## Bot policy `balanced` (VARIETY_SPEC 14.1, CONTENT 13): the reference competent player. Draft: scores every card
## (PolicyScoring), rerolls an offer whose best card scores below 2 under its Scrap rule, patches a hurt core, then
## picks the best. Route: hot on a healthy core when the hot reward is a crate, a double pick or a rare draft. Crates:
## the best tier per role, level-ups of duplicates, scrap otherwise (PolicyLoadout). Combat: swaps to the area weapon
## on a crowd and back (PolicyLoadout), and uses the abilities and calls by the heuristics of PolicyAbilities.
## `bot.route_mode` forces every route choice to the standard or the hot option (the scorecard's S14 runs); `risk` is
## this policy with another taste in cards and routes (PolicyRisk).
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
		PhaseState.Await.SALVAGE:
			bot.send(world, SimCommand.Kind.SALVAGE, PolicyLoadout.balanced_salvage_arg(world))
		PhaseState.Await.DRAFT:
			answer_draft(world, bot)
		PhaseState.Await.ROUTE:
			bot.send(world, SimCommand.Kind.PICK_ROUTE, route(world, bot))
		_:
			bot.send(world, SimCommand.Kind.SKIP_INTERMISSION, 0)


## The route option: forced by `bot.route_mode`, else the judgement of PolicyScoring.route_choice.
static func route(world: SimWorld, bot: PolicyBot) -> int:
	match bot.route_mode:
		PolicyBot.RouteMode.STANDARD:
			return PolicyTaste.route_standard(world)
		PolicyBot.RouteMode.HOT:
			return PolicyTaste.route_hot(world)
		_:
			return PolicyScoring.route_choice(world)


## Patch, reroll, buy a card out, patch with spare Scrap or pick: one step of the draft per call, in that order (PolicySpend
## holds the Scrap rules). Neither a reroll nor a buy-out is considered once a card of the offer was taken (a double pick), and
## each is capped per draft so the bot cannot loop.
static func answer_draft(world: SimWorld, bot: PolicyBot) -> void:
	bot.note_draft(world.draft.offer_ordinal)
	var slot: int = PolicyScoring.best_slot(world)
	if slot < 0:
		bot.send(world, SimCommand.Kind.SKIP_DRAFT, 0)
		return
	if not world.draft.offer.has(-1):
		if wants_patch(world, bot):
			bot.draft_patches += 1
			bot.send(world, SimCommand.Kind.PATCH_CORE, 0)
			return
		if wants_reroll(world, bot):
			bot.draft_rerolls += 1
			bot.send(world, SimCommand.Kind.REROLL, 0)
			return
		if PolicySpend.wants_buyout(world):
			bot.send(world, SimCommand.Kind.BUY_OUT, slot)
			return
	if PolicySpend.wants_patch(world, bot):
		bot.draft_patches += 1
		bot.send(world, SimCommand.Kind.PATCH_CORE, 0)
		return
	bot.send(world, SimCommand.Kind.PICK_DIRECTIVE, slot)


## Reroll when the best card scores below 2 and a free charge is left, or the Scrap held is 150 or more and covers
## the price the draft asks.
static func wants_reroll(world: SimWorld, bot: PolicyBot) -> bool:
	return reroll_pays(world, bot, DraftSystem.reroll_cost(world))


## The reroll rule for a given Scrap price of the next reroll (0 while a free charge is left).
static func reroll_pays(world: SimWorld, bot: PolicyBot, cost: int) -> bool:
	if world.draft.reroll_locked or bot.draft_rerolls >= PolicyScoring.MAX_REROLLS_PER_DRAFT:
		return false
	if PolicyScoring.best_score(world) >= PolicyScoring.REROLL_BELOW:
		return false
	if world.draft.free_rerolls > 0:
		return true
	return cost > 0 and world.scrap >= maxi(PolicyScoring.REROLL_SCRAP, cost)


## Patch a core below 60% when 150 Scrap is left after paying the price the draft asks.
static func wants_patch(world: SimWorld, bot: PolicyBot) -> bool:
	return patch_pays(world, bot, DraftSystem.patch_cost(world))


## The patch rule for a given Scrap price of the next patch.
static func patch_pays(world: SimWorld, bot: PolicyBot, cost: int) -> bool:
	if bot.draft_patches >= PolicyScoring.MAX_PATCHES_PER_DRAFT:
		return false
	if PolicySenses.core_fraction(world) >= PolicyScoring.PATCH_CORE:
		return false
	return cost > 0 and world.scrap >= cost + PolicyScoring.REROLL_SCRAP
