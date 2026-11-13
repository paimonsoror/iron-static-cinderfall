class_name ArchiveTestTree
extends RefCounted
## Test helper (V4-M): the complete Archive of VARIETY_CONTENT 11 and 12 (24 unlocks, 6 kits, the tier gates and the 13
## milestones, tests/fixtures/saves/unlocks_full.json) laid over the frozen variety fixture. The shipped data/unlocks.json
## holds only the rows whose items exist in the data of the day, so the tree rules are tested on this content.

const TREE: String = "res://tests/fixtures/saves/unlocks_full.json"
const TOTAL_COST: int = 5250  ## every unlock
const STRETCH_COST: int = 600  ## the two stretch turret types
const MILESTONE_TOTAL: int = 1050


## A fresh variety ContentSet whose unlocks, kits, tier gates and milestones are the complete tree.
static func content() -> ContentSet:
	var cs: ContentSet = TestContent.variety()
	cs.unlocks.clear()
	cs.kits.clear()
	cs.run.milestones.clear()
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREE))
	var r: JsonRead = JsonRead.new("unlocks_full.json")
	var tree: Dictionary = doc
	VarietyMetaLoader.unlocks(r, tree, cs)
	assert(r.errors.is_empty(), "the tree fixture does not load: " + "; ".join(r.errors))
	return cs


## The ids of the unlocks of `branch` (UnlockDef.Branch) at `tier`.
static func ids_at(cs: ContentSet, branch: int, tier: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for u: UnlockDef in cs.unlocks:
		if u.branch == branch and u.tier == tier:
			out.append(u.id)
	return out


## Gives the profile `data` and buys `ids` in order through Save.purchase_unlock; the Reason.Id of the first refusal,
## else OK.
static func buy_all(ids: Array[StringName], data: int) -> int:
	Save.profile.data = data
	for id: StringName in ids:
		var reason: int = Save.purchase_unlock(id)
		if reason != Reason.Id.OK:
			return reason
	return Reason.Id.OK
