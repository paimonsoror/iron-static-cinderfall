class_name ArchiveModel
extends RefCounted
## What the Archive screen shows, worked out from the content (`data/unlocks.json`) and an `ArchiveBank` (GDD 8.5, VARIETY_SPEC
## 11.6): the rows of a branch in tier order, which tiers are open (tier 2 after 3 unlocks of any kind, tier 3 after 8: the
## gates come from `content.run.tier_gates`), and the state of every row. A purchase waiting for its UNDO window holds its price
## back (`reserved`) so the shown Data and the row states already count it. Pure data: it builds no node.

enum State { OWNED, AVAILABLE, POOR, TIER_LOCKED, PENDING }

const BRANCHES: Array[int] = [
	UnlockDef.Branch.ARMORY, UnlockDef.Branch.DIRECTIVES, UnlockDef.Branch.KITS, UnlockDef.Branch.FIELD,
]

var content: ContentSet
var bank: ArchiveBank
var pending: StringName = &""  ## the purchase in its UNDO window, or &""
var reserved: int = 0  ## its price


func _init(for_content: ContentSet, for_bank: ArchiveBank) -> void:
	content = for_content
	bank = for_bank


## True when `tier` is open after `owned` unlocks: tier 1 always, tier n after tier_gates[n - 2] of them.
static func tier_is_open(cs: ContentSet, owned: int, tier: int) -> bool:
	return owned >= gate(cs, tier)


## The unlocks needed to open `tier` (0 for tier 1 or a tier without a gate).
static func gate(cs: ContentSet, tier: int) -> int:
	if tier <= 1 or cs == null or cs.run == null:
		return 0
	var at: int = tier - 2
	return cs.run.tier_gates[at] if at < cs.run.tier_gates.size() else 0


## The rows of `branch`, tier first and the file's order within a tier.
func rows(branch: int) -> Array[UnlockDef]:
	var out: Array[UnlockDef] = []
	for def: UnlockDef in content.unlocks:
		if def.branch == branch:
			out.append(def)
	out.sort_custom(func(a: UnlockDef, b: UnlockDef) -> bool: return a.tier < b.tier or (a.tier == b.tier and a.index < b.index))
	return out


## The tiers that have a row in `branch` (ascending).
func tiers(branch: int) -> Array[int]:
	var out: Array[int] = []
	for def: UnlockDef in rows(branch):
		if not out.has(def.tier):
			out.append(def.tier)
	return out


func owned_total() -> int:
	return bank.owned_count()


func tier_open(tier: int) -> bool:
	return tier_is_open(content, owned_total(), tier)


## Recovered Data not held back by a pending purchase.
func data() -> int:
	return bank.data() - reserved


func state(def: UnlockDef) -> int:
	if def.id == pending:
		return State.PENDING
	if bank.owns(def.id):
		return State.OWNED
	if not tier_open(def.tier):
		return State.TIER_LOCKED
	return State.AVAILABLE if data() >= def.cost else State.POOR


## Starts a purchase's UNDO window: the price is held back, nothing is bought yet. False when the row cannot be bought now.
func hold(def: UnlockDef) -> bool:
	if pending != &"" or state(def) != State.AVAILABLE:
		return false
	pending = def.id
	reserved = def.cost
	return true


## UNDO: the held purchase is dropped.
func release() -> void:
	pending = &""
	reserved = 0


## The window ended (or the screen closed): buys the held row. A Reason.Id (OK when nothing was held either).
func commit() -> int:
	if pending == &"":
		return Reason.Id.OK
	var id: StringName = pending
	release()
	return bank.purchase(id)


## The unlock the player can buy now: the dearest of what the Data covers (the one-more-run hook of the results screen), or
## null when nothing is affordable.
func best_affordable() -> UnlockDef:
	var best: UnlockDef = null
	for def: UnlockDef in content.unlocks:
		if state(def) == State.AVAILABLE and (best == null or def.cost > best.cost):
			best = def
	return best


## The cheapest row of an open tier that more Data would buy, or null.
func next_goal() -> UnlockDef:
	var best: UnlockDef = null
	for def: UnlockDef in content.unlocks:
		if state(def) == State.POOR and (best == null or def.cost < best.cost):
			best = def
	return best


## The name key of a row: the weapon, directive pack, kit or field option it grants.
static func display_name(def: UnlockDef) -> String:
	return Strings.t(def.name_key) if RunUi.has_key(def.name_key) else String(def.id).trim_prefix("u_").to_upper()


## The rules text of a row (`archive.<id>.desc`), or "".
static func description(def: UnlockDef) -> String:
	return RunUi.opt(def.name_key.trim_suffix(".name") + ".desc")
