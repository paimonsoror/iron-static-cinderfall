class_name ArchiveRules
extends RefCounted
## The rules of the Archive (VARIETY_SPEC 8.2 and 8.4, CONTENT 11 and 12) as pure functions of a Profile and the
## ContentSet. `Save.purchase_unlock` is the only writer; the Archive screen asks the same functions to draw a row
## (owned, locked behind a tier, too dear) so the screen and the purchase can never disagree.
##
## An unlock counts toward a tier gate when the profile owns it AND this content knows it: the id of an unlock from a
## newer build is kept in the file and otherwise ignored.


## How many of the unlocks of `content` the profile owns.
static func owned_count(p: Profile, content: ContentSet) -> int:
	var n: int = 0
	for u: UnlockDef in content.unlocks:
		if p.unlocks.has(String(u.id)):
			n += 1
	return n


## Unlocks needed before `tier` opens: tier 1 is open from the start, tier 2 needs `tier_gates[0]`, tier 3 `tier_gates[1]`.
## -1 for a tier the content does not have.
static func unlocks_needed(content: ContentSet, tier: int) -> int:
	if content.run == null or tier < 1:
		return -1
	if tier == 1:
		return 0
	var gate: int = tier - 2
	if gate >= content.run.tier_gates.size():
		return -1
	return content.run.tier_gates[gate]


static func tier_open(p: Profile, content: ContentSet, tier: int) -> bool:
	var needed: int = unlocks_needed(content, tier)
	return needed >= 0 and owned_count(p, content) >= needed


## Why `id` cannot be bought now: Reason.Id.OK when it can. The checks run in this order and the first failure wins:
## unknown id (UNKNOWN_ID), already owned (DUPLICATE_COMMAND), its tier is closed (PREREQ_NOT_MET), not enough Data
## (INSUFFICIENT_SCRAP; the currency is Recovered Data).
static func block_reason(p: Profile, content: ContentSet, id: StringName) -> int:
	var def: UnlockDef = content.unlock(id)
	if def == null:
		return Reason.Id.UNKNOWN_ID
	if p.unlocks.has(String(id)):
		return Reason.Id.DUPLICATE_COMMAND
	if not tier_open(p, content, def.tier):
		return Reason.Id.PREREQ_NOT_MET
	if p.data < def.cost or p.unlocks.size() >= Profile.MAX_UNLOCKS:
		return Reason.Id.INSUFFICIENT_SCRAP
	return Reason.Id.OK


## True when the kit exists and the profile may start a run with it: the free kit, or a kit whose unlock is owned.
static func kit_ready(p: Profile, content: ContentSet, kit_id: StringName) -> bool:
	var def: KitDef = content.kit(kit_id)
	if def == null:
		return false
	return def.cost == 0 or p.unlocks.has(String(kit_id))


## The Daily Run opens after the first kill of an act I boss (CONTENT 12: it is not an unlock).
static func daily_open(p: Profile, content: ContentSet) -> bool:
	for b: BossDef in content.bosses:
		var kills: int = p.boss_kills.get(String(b.id), 0)
		if b.pool_act == 1 and kills > 0:
			return true
	return false
