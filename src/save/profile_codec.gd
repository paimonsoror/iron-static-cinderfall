class_name ProfileCodec
extends RefCounted
## Profile <-> JSON text (ARCH 7.5). Plain, human-readable JSON. decode never trusts the file: it checks types and
## ranges, turns negatives into 0, ignores unknown keys and never executes anything or loads a path from the file.
## A file is unusable (profile == null) only when it is not a JSON object or has no valid schema_version; any
## other damage is sanitized field by field (a wrong type falls back to the default).
##
## Two schemas are read. A v2 document is read field by field. A v1 document (the build before the Archive) is migrated
## on the way in (VARIETY_SPEC 13.3): every v1 field is kept as it is, `data_lifetime` is the Data in hand, the new lists
## are empty (nothing is unlocked for free), the kit is the standard one and `best_wave` is the five waves of the old
## run when a mission was completed, else 0. A key that only exists in v2 is ignored in a v1 document.


static func encode(p: Profile) -> String:
	var runs: Array = []
	var first: int = maxi(0, p.awarded_run_ids.size() - Profile.MAX_AWARDED)
	for i: int in range(first, p.awarded_run_ids.size()):
		runs.append(p.awarded_run_ids[i])
	var settings: Dictionary = {}
	for k: StringName in p.settings:
		settings[String(k)] = p.settings[k]
	var doc: Dictionary = {
		"schema_version": Profile.SCHEMA_VERSION,
		"data": clampi(p.data, 0, Profile.MAX_COUNT),
		"data_lifetime": clampi(p.data_lifetime, 0, Profile.MAX_COUNT),
		"missions_completed": clampi(p.missions_completed, 0, Profile.MAX_COUNT),
		"best_core_hp": clampi(p.best_core_hp, 0, Profile.MAX_COUNT),
		"runs_played": clampi(p.runs_played, 0, Profile.MAX_COUNT),
		"awarded_run_ids": runs,
		"hints_seen": Array(p.hints_seen),
		"unlocks": Array(p.unlocks),
		"claimed": Array(p.claimed),
		"kit": String(p.kit),
		"codex_seen": Array(p.codex_seen),
		"best_wave": clampi(p.best_wave, 0, Profile.MAX_COUNT),
		"boss_kills": _tally_out(p.boss_kills),
		"victories_by_kit": _tally_out(p.victories_by_kit),
		"victory_weapons": Array(p.victory_weapons),
		"daily": _daily_out(p.daily),
		"settings": settings,
	}
	return JSON.stringify(doc, "\t") + "\n"


## `.profile` is null on failure and `.error` says why. `.schema_version` is set whenever the file declared one,
## so the caller can tell a newer file (schema_version > Profile.SCHEMA_VERSION) from a damaged one, and a v1 file
## (`.schema_version == 1`, already migrated in `.profile`) from a v2 one.
static func decode(text: String) -> ProfileDecodeResult:
	var r: ProfileDecodeResult = ProfileDecodeResult.new()
	if text.strip_edges().is_empty():
		r.error = "empty file"
		return r
	if text.length() > Profile.MAX_FILE_CHARS:
		r.error = "file too large (%d characters)" % text.length()
		return r
	var json: JSON = JSON.new()  # the instance API reports errors instead of printing them
	if json.parse(text) != OK:
		r.error = "invalid JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()]
		return r
	if typeof(json.data) != TYPE_DICTIONARY:
		r.error = "top level is not a JSON object"
		return r
	var doc: Dictionary = json.data
	var version: int = _whole(doc.get("schema_version"), -1)
	if version < 1:
		r.error = "missing or invalid schema_version"
		return r
	r.schema_version = version
	if version > Profile.SCHEMA_VERSION:
		r.error = "schema_version %d is newer than %d" % [version, Profile.SCHEMA_VERSION]
		return r
	var p: Profile = Profile.defaults()
	p.data = _count(doc.get("data"))
	p.missions_completed = _count(doc.get("missions_completed"))
	p.best_core_hp = _count(doc.get("best_core_hp"))
	p.runs_played = _count(doc.get("runs_played"))
	p.awarded_run_ids = _ids(doc.get("awarded_run_ids"), Profile.MAX_AWARDED)
	p.hints_seen = _ids(doc.get("hints_seen"), Profile.MAX_HINTS)
	_settings(p, doc.get("settings"))
	if version == 1:
		p.data_lifetime = p.data
		p.best_wave = Profile.V1_BEST_WAVE if p.missions_completed > 0 else 0
	else:
		_read_v2(p, doc)
	r.profile = p
	return r


## The fields that only exist from schema 2 on.
static func _read_v2(p: Profile, doc: Dictionary) -> void:
	p.data_lifetime = _count(doc.get("data_lifetime"))
	p.unlocks = _ids(doc.get("unlocks"), Profile.MAX_UNLOCKS)
	p.claimed = _ids(doc.get("claimed"), Profile.MAX_CLAIMED)
	var kit_v: Variant = doc.get("kit")
	if typeof(kit_v) == TYPE_STRING:
		var kit_text: String = kit_v
		if not kit_text.is_empty() and kit_text.length() <= Profile.MAX_ID_LENGTH:
			p.kit = StringName(kit_text)
	p.codex_seen = _ids(doc.get("codex_seen"), Profile.MAX_CODEX)
	p.best_wave = _count(doc.get("best_wave"))
	p.boss_kills = _tally_in(doc.get("boss_kills"))
	p.victories_by_kit = _tally_in(doc.get("victories_by_kit"))
	p.victory_weapons = _ids(doc.get("victory_weapons"), Profile.MAX_WEAPONS)
	p.daily = _daily_in(doc.get("daily"))


## A whole number as int, else `fallback`. JSON numbers arrive as float.
static func _whole(v: Variant, fallback: int) -> int:
	if typeof(v) == TYPE_INT:
		var n: int = v
		return n
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if is_finite(f) and f == floorf(f) and absf(f) <= float(Profile.MAX_COUNT):
			return int(f)
	return fallback


## A counter: non-numbers become 0, fractions round down, negatives become 0, huge values are capped.
static func _count(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		var n: int = v
		return clampi(n, 0, Profile.MAX_COUNT)
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if is_finite(f):
			return int(clampf(floorf(f), 0.0, float(Profile.MAX_COUNT)))
	return 0


## A list of short non-empty strings without duplicates; keeps the newest (last) `cap` entries.
static func _ids(v: Variant, cap: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if typeof(v) != TYPE_ARRAY:
		return out
	var rows: Array = v
	for item: Variant in rows:
		if typeof(item) != TYPE_STRING:
			continue
		var s: String = item
		if s.is_empty() or s.length() > Profile.MAX_ID_LENGTH or out.has(s):
			continue
		out.append(s)
	while out.size() > cap:
		out.remove_at(0)
	return out


## Known keys only; a value of the wrong type or outside its range keeps the default.
static func _settings(p: Profile, v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		return
	var src: Dictionary = v
	for key: StringName in p.settings.keys():
		if not src.has(String(key)):
			continue
		var raw: Variant = src[String(key)]
		if typeof(raw) == TYPE_FLOAT:  # JSON has no ints: 2.0 means 2
			raw = _whole(raw, -1)
		if Profile.setting_is_valid(key, raw):
			p.settings[key] = raw


## {id: count}: ids that are short non-empty strings, counts that are counters above 0, at most MAX_TALLY entries.
static func _tally_in(v: Variant) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = v
	for key: Variant in src.keys():
		if typeof(key) != TYPE_STRING or out.size() >= Profile.MAX_TALLY:
			continue
		var id: String = key
		var n: int = _count(src[key])
		if not id.is_empty() and id.length() <= Profile.MAX_ID_LENGTH and n > 0:
			out[id] = n
	return out


static func _tally_out(tally: Dictionary[String, int]) -> Dictionary:
	var out: Dictionary = {}
	for id: String in tally:
		out[id] = clampi(tally[id], 0, Profile.MAX_COUNT)
	return out


## The Daily Run record. A date that is not YYYY-MM-DD voids the whole record.
static func _daily_in(v: Variant) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = Profile.empty_daily()
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = v
	var date_v: Variant = src.get("date")
	if typeof(date_v) != TYPE_STRING:
		return out
	var date: String = date_v
	if not Profile.is_date(date):
		return out
	out["date"] = date
	out["best_wave"] = _count(src.get("best_wave"))
	out["won"] = src.get("won") == true
	out["rewarded"] = src.get("rewarded") == true
	return out


static func _daily_out(daily: Dictionary[String, Variant]) -> Dictionary:
	var date: String = str(daily.get("date", ""))
	if not Profile.is_date(date):
		return Profile.empty_daily()
	var best: int = 0
	var best_v: Variant = daily.get("best_wave")
	if typeof(best_v) == TYPE_INT:
		var n: int = best_v
		best = clampi(n, 0, Profile.MAX_COUNT)
	return {"date": date, "best_wave": best, "won": daily.get("won") == true, "rewarded": daily.get("rewarded") == true}
