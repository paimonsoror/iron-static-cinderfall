class_name SaveArchiveBank
extends ArchiveBank
## The Archive's bank bound to the `Save` autoload: the profile in memory is `Save.profile`; a purchase is `Save.purchase_unlock`
## (atomic: tier gate, not owned, funds; debit; add; flush; signals) and the kit is `Save.set_kit`. Both are called by name so
## this file stands on the profile v1 build too: when `Save` has no such method (before task V4-M merges) the same rules run
## on `Save.profile` here and the profile is flushed, so the screens work either way.


func _init(for_content: ContentSet = null) -> void:
	super._init(Save.profile, for_content)


func data() -> int:
	return Save.profile.data


func owns(id: StringName) -> bool:
	return Save.has_unlock(id)


func kit() -> StringName:
	return Save.profile.kit


func set_kit(id: StringName) -> void:
	if Save.has_method(&"set_kit"):
		Save.call(&"set_kit", id)
		return
	Save.profile.kit = id
	var _ok: bool = Save.flush()
	Events.profile_changed.emit()


func purchase(id: StringName) -> int:
	if Save.has_method(&"purchase_unlock"):
		var result: Variant = Save.call(&"purchase_unlock", id)
		var code: int = result
		return code
	profile = Save.profile
	var outcome: int = super.purchase(id)
	if outcome == Reason.Id.OK:
		var _ok: bool = Save.flush()
		Events.profile_changed.emit()
		Events.unlock_purchased.emit(id)
	return outcome
