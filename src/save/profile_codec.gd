class_name ProfileCodec
extends RefCounted
## Profile <-> JSON text (ARCH 7.5). Plain, human-readable JSON. decode never trusts the file: it checks types and
## ranges, turns negatives into 0, ignores unknown keys and never executes anything or loads a path from the file.
## A file is unusable (profile == null) only when it is not a JSON object or has no valid schema_version; any
## other damage is sanitized field by field (a wrong type falls back to the default).


static func encode(p: Profile) -> String:
	var runs: Array = []
	var first: int = maxi(0, p.awarded_run_ids.size() - Profile.MAX_AWARDED)
	for i: int in range(first, p.awarded_run_ids.size()):
		runs.append(p.awarded_run_ids[i])
	var hints: Array = []
	for h: String in p.hints_seen:
		hints.append(h)
	var settings: Dictionary = {}
	for k: StringName in p.settings:
		settings[String(k)] = p.settings[k]
	var doc: Dictionary = {
		"schema_version": Profile.SCHEMA_VERSION,
		"data": clampi(p.data, 0, Profile.MAX_COUNT),
		"missions_completed": clampi(p.missions_completed, 0, Profile.MAX_COUNT),
		"best_core_hp": clampi(p.best_core_hp, 0, Profile.MAX_COUNT),
		"runs_played": clampi(p.runs_played, 0, Profile.MAX_COUNT),
		"awarded_run_ids": runs,
		"hints_seen": hints,
		"settings": settings,
	}
	# The two profile v2 fields this build reads are written only when they hold something, so the file of a profile
	# without unlocks stays exactly the v1 file.
	if not p.unlocks.is_empty():
		doc["unlocks"] = Array(p.unlocks)
	if p.kit != Profile.DEFAULT_KIT and p.kit != &"":
		doc["kit"] = String(p.kit)
	return JSON.stringify(doc, "\t") + "\n"


## `.profile` is null on failure and `.error` says why. `.schema_version` is set whenever the file declared one,
## so the caller can tell a newer file (schema_version > Profile.SCHEMA_VERSION) from a damaged one.
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
	p.unlocks = _ids(doc.get("unlocks"), Profile.MAX_UNLOCKS)
	var kit_v: Variant = doc.get("kit")
	if typeof(kit_v) == TYPE_STRING:
		var kit_text: String = kit_v
		if not kit_text.is_empty() and kit_text.length() <= Profile.MAX_ID_LENGTH:
			p.kit = StringName(kit_text)
	r.profile = p
	return r


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
