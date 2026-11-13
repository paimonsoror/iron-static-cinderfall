class_name PolicyDraft
extends RefCounted
## How the specialist bots answer a draft (CONTENT 13): the cards of the categories they favour first, the best score
## inside the first category the offer shows, and the `balanced` answer (PolicyBalanced.answer_draft) when it shows none.
## `hoarder` rerolls first while it holds 200 Scrap; `risk` takes a corrupted card whenever one is
## offered. One command per call; deterministic; no stream.

## `hoarder`: reroll an offer with no weapon directive while this much Scrap is held (and covers the price).
const HOARDER_REROLL_SCRAP: int = 200


## Pick the best card of the first favoured category on offer. With none on offer: reroll when `reroll_scrap` is above 0
## and the Scrap held covers it. Otherwise answer like `balanced` (patch, reroll, pick) when `fall_back_to_balanced`,
## else just take the best-scoring card (the `hoarder` saves its Scrap for the weapon rerolls).
static func answer_favouring(
	world: SimWorld, bot: PolicyBot, categories: Array[int], reroll_scrap: int = 0, fall_back_to_balanced: bool = true
) -> void:
	bot.note_draft(world.draft.offer_ordinal)
	var slot: int = PolicyTaste.best_slot_in(world, categories)
	if slot >= 0:
		bot.send(world, SimCommand.Kind.PICK_DIRECTIVE, slot)
		return
	if reroll_scrap > 0 and rerolls(world, bot, reroll_scrap):
		bot.draft_rerolls += 1
		bot.send(world, SimCommand.Kind.REROLL, 0)
		return
	if fall_back_to_balanced:
		PolicyBalanced.answer_draft(world, bot)
		return
	var best: int = PolicyScoring.best_slot(world)
	if best >= 0:
		bot.send(world, SimCommand.Kind.PICK_DIRECTIVE, best)
	else:
		bot.send(world, SimCommand.Kind.SKIP_DRAFT, 0)


## `risk`: a corrupted card when the offer has one, else the `balanced` answer.
static func answer_risk(world: SimWorld, bot: PolicyBot) -> void:
	bot.note_draft(world.draft.offer_ordinal)
	var slot: int = PolicyTaste.corrupted_slot(world)
	if slot >= 0:
		bot.send(world, SimCommand.Kind.PICK_DIRECTIVE, slot)
		return
	PolicyBalanced.answer_draft(world, bot)


## A reroll is possible (not locked, not after a card was taken, under the cap) and `scrap_floor` Scrap is held, which
## also covers the price. A free charge costs nothing but the floor still applies.
static func rerolls(world: SimWorld, bot: PolicyBot, scrap_floor: int) -> bool:
	if world.draft.reroll_locked or world.draft.offer.has(-1) or bot.draft_rerolls >= PolicyScoring.MAX_REROLLS_PER_DRAFT:
		return false
	var cost: int = DraftSystem.reroll_cost(world)
	if world.draft.free_rerolls <= 0 and cost <= 0:
		return false
	return world.scrap >= maxi(scrap_floor, cost)
