extends Node
## `Save` autoload (ARCH 7.5). Wave 0 stub: an in-memory default profile with the API present.
## TODO(W1-D): disk persistence, backup, corruption handling, validation.

enum LoadStatus { OK, NEW_PROFILE, RECOVERED_FROM_BACKUP, RESET_AFTER_CORRUPTION, NEWER_SCHEMA_SET_ASIDE }

var profile: Profile = Profile.defaults()
var last_load_status: int = LoadStatus.NEW_PROFILE
var _fs: SaveFs = MemorySaveFs.new()


## Tests inject a MemorySaveFs, then call load_profile().
func use_fs(fs: SaveFs) -> void:
	_fs = fs


func load_profile() -> int:
	# TODO(W1-D)
	profile = Profile.defaults()
	last_load_status = LoadStatus.NEW_PROFILE
	return last_load_status


## Write tmp, verify by re-reading, keep the previous file as .bak, rename.
func flush() -> bool:
	# TODO(W1-D)
	return true


## False and no change if run_id was already awarded. Stub: in-memory only.
func grant_run_reward(run_id: String, result: int, data_amount: int, core_hp: int) -> bool:
	# TODO(W1-D)
	if profile.awarded_run_ids.has(run_id):
		return false
	profile.data += data_amount
	profile.runs_played += 1
	if result == RunResult.Id.VICTORY:
		profile.missions_completed += 1
		profile.best_core_hp = maxi(profile.best_core_hp, core_hp)
	profile.awarded_run_ids.append(run_id)
	Events.profile_changed.emit()
	return true


func get_setting(key: StringName) -> Variant:
	return profile.settings.get(key)


## Stub: no type validation yet.
func set_setting(key: StringName, value: Variant) -> void:
	# TODO(W1-D)
	if not profile.settings.has(key):
		return
	profile.settings[key] = value
	Events.settings_changed.emit(key)


func mark_hint_seen(key: String) -> void:
	# TODO(W1-D)
	if not profile.hints_seen.has(key):
		profile.hints_seen.append(key)


func has_seen_hint(key: String) -> bool:
	return profile.hints_seen.has(key)
