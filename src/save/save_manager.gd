extends Node
## `Save` autoload (ARCH 7.5): the profile on disk. Crash-safe: flush writes a temp file, verifies it by reading it
## back, keeps the previous good file as .bak and renames the temp file over the main one. A damaged main file is
## recovered from .bak or set aside as .corrupt; a file from a newer schema is copied to .newer and never lost.
## Profile v2 lives in `user://profile_v2.json`; a profile of the build before the Archive (`profile_v1.json`) is
## migrated once and its files are never touched (ProfileMigration). Rewards are granted once per run id, together with
## the milestones and records the run earned (RewardLedger). Archive purchases are atomic (ArchiveRules). The run file
## of a run in progress (`user://run_v1.json`, RunStore) is written through `save_run`, `load_run` and `clear_run`; a
## resumed run keeps its run id, so it is rewarded once.

enum LoadStatus {
	OK, NEW_PROFILE, RECOVERED_FROM_BACKUP, RESET_AFTER_CORRUPTION, NEWER_SCHEMA_SET_ASIDE,
	MIGRATED_FROM_V1,  ## profile_v2.json was written from profile_v1.json (the v1 files stay as they were)
}

const PATH_MAIN: String = "user://profile_v2.json"
const PATH_TMP: String = "user://profile_v2.json.tmp"
const PATH_BAK: String = "user://profile_v2.json.bak"
const PATH_CORRUPT: String = "user://profile_v2.json.corrupt"
const PATH_NEWER: String = "user://profile_v2.json.newer"
const MAX_ASIDE_COPIES: int = 8  ## .corrupt and .newer keep up to this many copies (.corrupt, .corrupt.1, ...)

var profile: Profile = Profile.defaults()
var last_load_status: int = LoadStatus.NEW_PROFILE
## What the latest `grant_run_reward` added, for the results screen: { "run_id": String, "run_data": int,
## "milestones": [ { "id": String, "data": int } ], "milestone_data": int, "total": int, "daily": "" | "rewarded" | "practice" }.
## {} until a run is granted and after a reload.
var last_reward: Dictionary = {}
var _fs: SaveFs = DiskSaveFs.new()
var _content: ContentSet = null  ## tests inject one with use_content; the game reads Content.db
var _protect_main: bool = false  ## a newer-schema file could not be copied aside, so flush must not overwrite it
var _dirty: bool = false  ## the profile in memory has changes that no successful flush has written yet


func _ready() -> void:
	load_profile()
	Log.info("Save", "profile %s data=%d runs=%d" % [LoadStatus.keys()[last_load_status], profile.data, profile.runs_played])


## Tests inject a MemorySaveFs, then call load_profile().
func use_fs(fs: SaveFs) -> void:
	_fs = fs


## Tests inject a ContentSet (the Archive tree, the milestone table, the kits); null goes back to `Content.db`.
func use_content(content: ContentSet) -> void:
	_content = content


## Main file; if it is missing, the temp file or the backup, else the v1 profile (MIGRATED_FROM_V1), else NEW_PROFILE;
## if it is unreadable or invalid, .bak (RECOVERED_FROM_BACKUP); if that fails too, the bad file moves to .corrupt and
## the v1 profile or a fresh one starts (RESET_AFTER_CORRUPTION). A higher schema_version is copied to .newer and a
## fresh profile starts (NEWER_SCHEMA_SET_ASIDE). Never crashes, never deletes data.
func load_profile() -> int:
	_protect_main = false
	_dirty = false
	last_reward = {}
	profile = Profile.defaults()
	last_load_status = LoadStatus.NEW_PROFILE
	if not _fs.exists(PATH_MAIN):
		# flush renames main to .bak before moving .tmp into place; a crash in between leaves no main file
		var rescued: Profile = _first_valid([PATH_TMP, PATH_BAK])
		if rescued != null:
			profile = rescued
			last_load_status = LoadStatus.RECOVERED_FROM_BACKUP
			Log.warn("Save", "main profile missing; recovered from tmp or backup")
		else:
			_start_without_v2(false)
	else:
		_load_main()
	_settle_kit()
	return last_load_status


func _load_main() -> void:
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
			Log.warn("Save", "profile and backup unreadable (%s); set aside" % decoded.error)
			_start_without_v2(true)


## There is no usable v2 file: migrate the v1 profile when there is one (and write profile_v2.json at once), else
## start fresh. `after_damage`: a v2 file existed and was set aside, so a fresh start is RESET_AFTER_CORRUPTION.
func _start_without_v2(after_damage: bool) -> void:
	last_load_status = LoadStatus.RESET_AFTER_CORRUPTION if after_damage else LoadStatus.NEW_PROFILE
	match ProfileMigration.inspect(_fs):
		ProfileMigration.Found.USABLE:
			profile = ProfileMigration.read(_fs)
			last_load_status = LoadStatus.MIGRATED_FROM_V1
			Log.info("Save", "profile migrated from v1 (data=%d, v1 files left as they were)" % profile.data)
			_persist()
		ProfileMigration.Found.NEWER:
			last_load_status = LoadStatus.NEWER_SCHEMA_SET_ASIDE if not after_damage else last_load_status
			Log.warn("Save", "profile_v1.json is from a newer schema; starting fresh and leaving it alone")
		ProfileMigration.Found.DAMAGED:
			last_load_status = LoadStatus.RESET_AFTER_CORRUPTION
			Log.warn("Save", "profile_v1.json is unreadable; starting fresh and leaving it alone")


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
## on VICTORY counts the mission and keeps the best core HP, remembers the id (newest 64), applies the run's `extras`
## (RewardLedger: best wave, boss kills, victories per kit and weapon, the milestones it earned and their Data, the Daily
## Run record), saves everything in one flush, emits `profile_changed`. The result is in `last_reward`. If the save
## fails the grant still stands in memory (a second call stays false).
func grant_run_reward(run_id: String, result: int, data_amount: int, core_hp: int, extras: Dictionary = {}) -> bool:
	if run_id.is_empty() or run_id.length() > Profile.MAX_ID_LENGTH or profile.awarded_run_ids.has(run_id):
		return false
	var report: Dictionary = RewardLedger.apply(profile, content_set(), result, data_amount, extras)
	var total: int = report["total"]
	profile.data = clampi(profile.data + total, 0, Profile.MAX_COUNT)
	profile.data_lifetime = clampi(profile.data_lifetime + total, 0, Profile.MAX_COUNT)
	profile.runs_played = mini(profile.runs_played + 1, Profile.MAX_COUNT)
	if result == RunResult.Id.VICTORY:
		profile.missions_completed = mini(profile.missions_completed + 1, Profile.MAX_COUNT)
		profile.best_core_hp = maxi(profile.best_core_hp, clampi(core_hp, 0, Profile.MAX_COUNT))
	profile.awarded_run_ids.append(run_id)
	while profile.awarded_run_ids.size() > Profile.MAX_AWARDED:
		profile.awarded_run_ids.remove_at(0)
	report["run_id"] = run_id
	last_reward = report
	_persist()
	Events.profile_changed.emit()
	return true


## The ContentSet the Archive rules read: the injected one, else the loaded game data. Null when neither exists.
func content_set() -> ContentSet:
	return _content if _content != null else Content.db


## True when the profile holds the unlock `id`.
func has_unlock(id: StringName) -> bool:
	return profile.unlocks.has(String(id))


## Buys the Archive unlock `id` with Recovered Data. Returns a Reason.Id: OK, or why not (ArchiveRules.block_reason:
## UNKNOWN_ID, DUPLICATE_COMMAND when owned, PREREQ_NOT_MET when its tier is closed, INSUFFICIENT_SCRAP when the Data
## in hand is short). Atomic: either the Data is debited and the id added together, or nothing changes. Saves at once,
## emits `profile_changed` and `unlock_purchased`.
func purchase_unlock(id: StringName) -> int:
	var cs: ContentSet = content_set()
	if cs == null:
		return Reason.Id.UNKNOWN_ID
	var reason: int = ArchiveRules.block_reason(profile, cs, id)
	if reason != Reason.Id.OK:
		return reason
	var def: UnlockDef = cs.unlock(id)
	profile.data = maxi(profile.data - def.cost, 0)
	profile.unlocks.append(String(id))
	_persist()
	Events.profile_changed.emit()
	Events.unlock_purchased.emit(id)
	return Reason.Id.OK


## Picks the kit of the next run. A kit the content does not know is refused (no change). Owning the kit is the
## Archive's rule (a locked kit cannot be tapped there, ArchiveRules.kit_ready says which): here a kit that is not
## owned is accepted and the next load puts the standard kit back, so a profile never keeps a kit it cannot start.
func set_kit(id: StringName) -> void:
	var cs: ContentSet = content_set()
	if cs == null or cs.kit(id) == null:
		Log.warn("Save", "kit '%s' refused (unknown)" % String(id))
		return
	if profile.kit == id:
		return
	profile.kit = id
	_persist()
	Events.profile_changed.emit()


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


## The codex entries the player has opened (ids are the UI's; the profile only remembers them).
func mark_codex_seen(key: String) -> void:
	if key.is_empty() or key.length() > Profile.MAX_ID_LENGTH or profile.codex_seen.has(key):
		return
	if profile.codex_seen.size() >= Profile.MAX_CODEX:
		return
	profile.codex_seen.append(key)
	_persist()


func has_codex_seen(key: String) -> bool:
	return profile.codex_seen.has(key)


func _persist() -> void:
	if not flush():
		Log.warn("Save", "profile not saved; it stays in memory and the next flush retries")


## A kit the profile cannot start a run with (a profile of another state, a hand-edited file) is the standard kit.
## In memory only: nothing is written until the next flush.
func _settle_kit() -> void:
	var cs: ContentSet = content_set()
	if cs != null and not cs.kits.is_empty() and not ArchiveRules.kit_ready(profile, cs, profile.kit):
		profile.kit = Profile.DEFAULT_KIT


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
