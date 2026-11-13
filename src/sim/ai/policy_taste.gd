class_name PolicyTaste
extends RefCounted
## What the specialist bots lean toward (CONTENT 13): the cards of a category, the corrupted cards, the route with a
## given reward, the hot and the standard route. Pure reads of the world; no stream, no memory. Everything goes by
## the category of a directive and the flags of a route option, never by the id of a directive, so a card or a pack
## added later is played without a change here. Ties between equal scores follow PolicyScoring.best_slot.


## The open slot that holds the best-scoring card of the first of `categories` (DirectiveDef.Category values, in order
## of preference) that the offer shows at all; -1 when the offer shows none of them.
static func best_slot_in(world: SimWorld, categories: Array[int]) -> int:
	for category: int in categories:
		var slot: int = _best_of(world, category, false)
		if slot >= 0:
			return slot
	return -1


## The open slot of the best-scoring corrupted card (category or rarity), -1 when the offer has none.
static func corrupted_slot(world: SimWorld) -> int:
	return _best_of(world, -1, true)


static func is_corrupted(d: DirectiveDef) -> bool:
	return d.category == DirectiveDef.Category.CORRUPTED or d.rarity == DirectiveDef.Rarity.CORRUPTED


## The index of the route option that carries `reward` (a RewardDef id), -1 when none does.
static func route_with_reward(world: SimWorld, reward: StringName) -> int:
	var options: Array[RouteOption] = PolicyAnswers.route_options(world)
	for i: int in options.size():
		if PolicyScoring.reward_id(world, options[i]) == reward:
			return i
	return -1


## The first hot option; option A when none is hot.
static func route_hot(world: SimWorld) -> int:
	var options: Array[RouteOption] = PolicyAnswers.route_options(world)
	for i: int in options.size():
		if options[i].hot:
			return i
	return 0


## The first standard option; option A when none is standard.
static func route_standard(world: SimWorld) -> int:
	var options: Array[RouteOption] = PolicyAnswers.route_options(world)
	for i: int in options.size():
		if not options[i].hot:
			return i
	return 0


## `category` -1 accepts every category; `corrupted_only` accepts only corrupted cards.
static func _best_of(world: SimWorld, category: int, corrupted_only: bool) -> int:
	var best: int = -1
	var top_score: float = 0.0
	var best_rank: int = 0
	for slot: int in PolicyAnswers.open_slots(world):
		var index: int = world.draft.offer[slot]
		var d: DirectiveDef = world.content.directives[index]
		if (category >= 0 and d.category != category) or (corrupted_only and not is_corrupted(d)):
			continue
		var s: float = PolicyScoring.score(world, index)
		var rank: int = PolicyScoring.CATEGORY_RANK[d.category]
		if best < 0 or s > top_score or (is_equal_approx(s, top_score) and rank > best_rank):
			best = slot
			top_score = s
			best_rank = rank
	return best
