extends Node
## `Save` autoload (ARCH 7.5): the profile on disk. Crash-safe: flush writes a temp file, verifies it by reading it
## back, keeps the previous good file as .bak and renames the temp file over the main one. A damaged main file is
## recovered from .bak or set aside as .corrupt; a file from a newer schema is copied to .newer and never lost.
## Rewards are granted once per run id. The run file of a run in progress (`user://run_v1.json`, RunStore) is written
## through `save_run`, `load_run` and `clear_run`; a resumed run keeps its run id, so it is rewarded once.

enum LoadStatus { OK, NEW_PROFILE, RECOVERED_FROM_BACKUP, RESET_AFTER_CORRUPTION, NEWER_SCHEMA_SET_ASIDE }

const PATH_MAIN: String = "user://profile_v1.json"
const PATH_TMP: String = "user://profile_v1.json.tmp"
const PATH_BAK: String = "user://profile_v1.json.bak"
const PATH_CORRUPT: String = "user://profile_v1.json.corrupt"
const PATH_NEWER: String = "user://profile_v1.json.newer"
const MAX_ASIDE_COPIES: int = 8  ## .corrupt and .newer keep up to this many copies (.corrupt, .corrupt.1, ...)

var profile: Profile = Profile.defaults()
var last_load_status: int = LoadStatus.NEW_PROFILE
var _fs: SaveFs = DiskSaveFs.new()
var _protect_main: bool = false  ## a newer-schema file could not be copied aside, so flush must not overwrite it
var _dirty: bool = false  ## the profile in memory has changes that no successful flush has written yet


func _ready() -> void:
	load_profile()
	Log.info("Save", "profile %s data=%d runs=%d" % [LoadStatus.keys()[last_load_status], profile.data, profile.runs_played])


## Tests inject a MemorySaveFs, then call load_profile().
func use_fs(fs: SaveFs) -> void:
	_fs = fs


## Main file; if it is missing, NEW_PROFILE; if unreadable or invalid, .bak (RECOVERED_FROM_BACKUP); if that fails
## too, the bad file moves to .corrupt and a fresh profile starts (RESET_AFTER_CORRUPTION). A higher schema_version
## is copied to .newer and a fresh profile starts (NEWER_SCHEMA_SET_ASIDE). Never crashes, never deletes data.
func load_profile() -> int:
	_protect_main = false
	_dirty = false
	profile = Profile.defaults()
	last_load_status = LoadStatus.NEW_PROFILE
	if not _fs.exists(PATH_MAIN):
		# flush renames main to .bak before moving .tmp into place; a crash in between leaves no main file
		var rescued: Profile = _first_valid([PATH_TMP, PATH_BAK])
		if rescued != null:
			profile = rescued
			last_load_status = LoadStatus.RECOVERED_FROM_BACKUP
			Log.warn("Save", "main profile missing; recovered from tmp or backup")
		return last_load_status
	var text: String = _fs.read(PATH_MAIN)
	var decoded: ProfileDecodeResult = ProfileCodec.decode(text)
	if decoded.profile != null:
		profile = decoded.profile
		last_load_status = LoadStatus.OK
	elif decoded.schema_version > Profile.SCHEMA_VERSION:
		_protect_main = not _keep_copy(PATH_NEWER, text)
		last_load_status = LoadStatus.NEWER_SCHEMA_SET_ASIDE
		Log.warn("Save", "profile has schema %d (this build reads %d); copied aside, starting fresh" % [decoded.schema_version, Profile.SCHEMA_VERSION])
	else:
		var backup: Profile = _first_valid([PATH_BAK])
		if backup != null:
			profile = backup
			last_load_status = LoadStatus.RECOVERED_FROM_BACKUP
			Log.warn("Save", "profile unreadable (%s); recovered from backup" % decoded.error)
		else:
			_move_aside(text)
			last_load_status = LoadStatus.RESET_AFTER_CORRUPTION
			Log.warn("Save", "profile and backup unreadable (%s); starting fresh" % decoded.error)
	return last_load_status


## Write tmp, verify by re-reading, keep the previous good file as .bak, rename tmp over main. False leaves the
## previous main file as it was.
func flush() -> bool:
	_dirty = true  # stays true unless this write completes
	if _protect_main:
		Log.warn("Save", "flush refused: the newer-schema file has no copy yet")
		return false
	var text: String = ProfileCodec.encode(profile)
	if not _fs.write(PATH_TMP, text) or _fs.read(PATH_TMP) != text:
		_fs.remove(PATH_TMP)
		return false
	var kept: bool = false
	if _fs.exists(PATH_MAIN) and ProfileCodec.decode(_fs.read(PATH_MAIN)).profile != null:
		if not _fs.rename(PATH_MAIN, PATH_BAK):  # only a good previous file becomes the backup
			_fs.remove(PATH_TMP)
			return false
		kept = true
	if not _fs.rename(PATH_TMP, PATH_MAIN):
		if kept:
			_fs.rename(PATH_BAK, PATH_MAIN)  # put the previous file back; tmp stays for recovery
		return false
	_dirty = false
	return true


## True while the profile in memory holds changes that no successful flush has written yet (the last write failed or
## was refused). `grant_run_reward` and the setters flush at once but cannot return a failed write; a caller that must
## know (GameRewards) reads this afterwards and retries with `flush()`.
func profile_dirty() -> bool:
	return _dirty


## False and no change if run_id was already awarded (or is not a usable id). Otherwise adds Data, counts the run,
## on VICTORY counts the mission and keeps the best core HP, remembers the id (newest 64), saves, emits
## `profile_changed`. If the save fails the grant still stands in memory (a second call stays false).
## `extras` (VARIETY_SPEC 13.3: milestones, best wave, boss kills, daily flags) is accepted and not read yet: those
## fields arrive with profile v2 (task V4-M).
@warning_ignore("unused_parameter")
func grant_run_reward(run_id: String, result: int, data_amount: int, core_hp: int, extras: Dictionary = {}) -> bool:
	if run_id.is_empty() or run_id.length() > Profile.MAX_ID_LENGTH or profile.awarded_run_ids.has(run_id):
		return false
	profile.data = clampi(profile.data + maxi(data_amount, 0), 0, Profile.MAX_COUNT)
	profile.runs_played = mini(profile.runs_played + 1, Profile.MAX_COUNT)
	if result == RunResult.Id.VICTORY:
		profile.missions_completed = mini(profile.missions_completed + 1, Profile.MAX_COUNT)
		profile.best_core_hp = maxi(profile.best_core_hp, clampi(core_hp, 0, Profile.MAX_COUNT))
	profile.awarded_run_ids.append(run_id)
	while profile.awarded_run_ids.size() > Profile.MAX_AWARDED:
		profile.awarded_run_ids.remove_at(0)
	_persist()
	Events.profile_changed.emit()
	return true


## True when the profile holds the unlock `id` (the list is filled by the Archive purchases of task V4-M).
func has_unlock(id: StringName) -> bool:
	return profile.unlocks.has(String(id))


## Writes the run file (atomic, as the profile). False leaves the previous run file as it was.
func save_run(doc: Dictionary) -> bool:
	return RunStore.save(_fs, doc)


## The run file as a Dictionary; {} when there is none or it cannot be read.
func load_run() -> Dictionary:
	return RunStore.load(_fs)


## Deletes the run file (the run ended).
func clear_run() -> void:
	RunStore.clear(_fs)


## Null for an unknown key.
func get_setting(key: StringName) -> Variant:
	return profile.settings.get(key)


## Unknown keys and values of the wrong type or range are rejected (no change, no signal).
func set_setting(key: StringName, value: Variant) -> void:
	if not Profile.setting_is_valid(key, value):
		Log.warn("Save", "setting '%s' rejected" % String(key))
		return
	profile.settings[key] = value
	_persist()
	Events.settings_changed.emit(key)


func mark_hint_seen(key: String) -> void:
	if key.is_empty() or key.length() > Profile.MAX_ID_LENGTH or profile.hints_seen.has(key):
		return
	if profile.hints_seen.size() >= Profile.MAX_HINTS:
		return
	profile.hints_seen.append(key)
	_persist()


func has_seen_hint(key: String) -> bool:
	return profile.hints_seen.has(key)


func _persist() -> void:
	if not flush():
		Log.warn("Save", "profile not saved; it stays in memory and the next flush retries")


## The first of `paths` that exists and decodes to a profile, else null.
func _first_valid(paths: Array[String]) -> Profile:
	for path: String in paths:
		if _fs.exists(path):
			var d: ProfileDecodeResult = ProfileCodec.decode(_fs.read(path))
			if d.profile != null:
				return d.profile
	return null


## Copies `text` to base, base.1, ... unless an identical copy is already there. True when a copy is verified.
func _keep_copy(base: String, text: String) -> bool:
	var target: String = base
	for k: int in MAX_ASIDE_COPIES:
		target = base if k == 0 else "%s.%d" % [base, k]
		if not _fs.exists(target):
			break
		if _fs.read(target) == text:
			return true
	return _fs.write(target, text) and _fs.read(target) == text


## Moves the unreadable main file to .corrupt (.corrupt.1, ... if taken). Falls back to a verified copy.
func _move_aside(text: String) -> void:
	var target: String = PATH_CORRUPT
	for k: int in MAX_ASIDE_COPIES:
		target = PATH_CORRUPT if k == 0 else "%s.%d" % [PATH_CORRUPT, k]
		if not _fs.exists(target):
			break
	if _fs.rename(PATH_MAIN, target):
		return
	if _keep_copy(PATH_CORRUPT, text):
		_fs.remove(PATH_MAIN)
