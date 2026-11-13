class_name PolicySpend
extends RefCounted
## What `balanced` does with Scrap that has no other use (V4-T). The shop is closed, so Scrap buys only what the draft
## sells: a second card (BUY_OUT), a reroll and a core patch. A player who ends a run with 900 Scrap in the bank has left
## cards and core on the table, so the bot spends what it does not need to keep: everything but nothing in the last
## draft before the final wave (nothing is left to save it for), everything above a reserve for rerolls before that.
## Pure functions of the world; no random stream.

## Cards worth less than this are not bought (a second card must be worth having).
const BUYOUT_MIN_WORTH: float = 1.5
## A core at or below this fraction of its maximum is patched with spare Scrap.
const SURPLUS_CORE: float = 0.9
const MAX_PATCHES: int = 3
## Scrap kept for rerolls and patches before the last draft.
const MID_RESERVE: int = 150


## The draft that is open sells the last cards before the final wave of the run.
static func is_last_draft(world: SimWorld) -> bool:
	return PolicySenses.next_wave(world) >= PhaseSystem.wave_count(world)


static func reserve(world: SimWorld) -> int:
	return 0 if is_last_draft(world) else MID_RESERVE


## Scrap that may be spent now.
static func spare(world: SimWorld) -> int:
	return world.scrap - reserve(world)


## The best worth among the open slots other than `skip`, -1000 when there is none.
static func second_best_worth(world: SimWorld, skip: int) -> float:
	var best: float = -1000.0
	for slot: int in PolicyAnswers.open_slots(world):
		if slot != skip:
			best = maxf(best, PolicyScoring.worth(world, world.draft.offer[slot]))
	return best


## Buy the best card out (take it and still pick another): once per draft, before anything was taken, when spare Scrap
## pays for it and the card that would be picked second is worth having.
static func wants_buyout(world: SimWorld) -> bool:
	var d: DraftState = world.draft
	if d.bought_out or d.offer.has(-1) or d.slots_left() < 2:
		return false
	if spare(world) < DraftSystem.buyout_cost(world):
		return false
	return second_best_worth(world, PolicyScoring.best_slot(world)) >= BUYOUT_MIN_WORTH


## Patch a wounded core with spare Scrap, up to MAX_PATCHES a draft.
static func wants_patch(world: SimWorld, bot: PolicyBot) -> bool:
	if world.draft.reroll_locked or bot.draft_patches >= MAX_PATCHES:
		return false
	if PolicySenses.core_fraction(world) > SURPLUS_CORE:
		return false
	var cost: int = DraftSystem.patch_cost(world)
	return cost > 0 and spare(world) >= cost
