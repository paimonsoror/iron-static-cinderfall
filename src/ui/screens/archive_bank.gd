class_name ArchiveBank
extends RefCounted
## The Archive's door to a profile: how much Recovered Data there is, which unlocks are owned, the chosen kit, and the
## purchase. This base class is an in-memory stand-in over a `Profile` that follows the purchase rules of GDD 8.5 (a tier gate,
## not owned, enough Data; debit; add the id), used by the sandboxes and the tests. `SaveArchiveBank` binds the same
## calls to the `Save` autoload (profile v2, task V4-M).

var profile: Profile
var content: ContentSet


func _init(for_profile: Profile = null, for_content: ContentSet = null) -> void:
	profile = for_profile if for_profile != null else Profile.defaults()
	content = for_content


func data() -> int:
	return profile.data


func owns(id: StringName) -> bool:
	return profile.unlocks.has(String(id))


## The unlocks owned that this content knows (an unknown id of a newer build's file is kept but never counted).
func owned_count() -> int:
	var n: int = 0
	if content == null:
		return n
	for def: UnlockDef in content.unlocks:
		if owns(def.id):
			n += 1
	return n


func kit() -> StringName:
	return profile.kit


func set_kit(id: StringName) -> void:
	profile.kit = id


## A Reason.Id: OK (bought), UNKNOWN_ID, DUPLICATE_COMMAND (owned), PREREQ_NOT_MET (the tier is closed) or INSUFFICIENT_SCRAP
## (not enough Data; the Archive words it as Data).
func purchase(id: StringName) -> int:
	var def: UnlockDef = content.unlock(id) if content != null else null
	if def == null:
		return Reason.Id.UNKNOWN_ID
	if owns(id):
		return Reason.Id.DUPLICATE_COMMAND
	if not ArchiveModel.tier_is_open(content, owned_count(), def.tier):
		return Reason.Id.PREREQ_NOT_MET
	if profile.data < def.cost:
		return Reason.Id.INSUFFICIENT_SCRAP
	profile.data -= def.cost
	profile.unlocks.append(String(id))
	return Reason.Id.OK
