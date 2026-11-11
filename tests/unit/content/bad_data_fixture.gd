class_name BadDataFixture
extends RefCounted
## Test helper. A bad fixture (tests/fixtures/data_bad/<id>.json) is the frozen baseline plus a list of patches:
##   { "rule": "...", "stage": "loader" | "validator",
##     "patches": [ { "file": "waves.json", "path": "waves[0].groups[0].count", "set": 0 },
##                  { "file": "waves.json", "path": "waves[2]", "delete": true } ],
##   "expect": [ "<exact error>", ... ] }
## `path` is dotted keys with [n] array indexes. The set value "$NAN" / "$INF" becomes a non-finite float (JSON
## cannot carry one). run() loads the patched files through the production pipeline (ContentLoader.build, then
## ContentValidator.validate when the loader had no errors, as Content.reload does).

const FIXTURE_DIR: String = "res://tests/fixtures/data_bad"

var rule: String = ""
var expect: PackedStringArray = PackedStringArray()
var expected_stage: String = ""
var errors: PackedStringArray = PackedStringArray()
var stage: String = ""  ## "loader" or "validator": which step produced the errors ("" when there were none)


static func run(fixture_id: String) -> BadDataFixture:
	var f: BadDataFixture = BadDataFixture.new()
	var spec: Dictionary = read_json("%s/%s.json" % [FIXTURE_DIR, fixture_id])
	f.rule = str(spec.get("rule", ""))
	f.expected_stage = str(spec.get("stage", ""))
	var expected: Array = spec.get("expect", [])
	for line: Variant in expected:
		f.expect.append(str(line))
	var docs: Dictionary = {}
	for file: String in ContentLoader.FILES:
		docs[file] = read_json("%s/%s" % [TestContent.BASELINE_DIR, file])
	var patches: Array = spec.get("patches", [])
	for patch_v: Variant in patches:
		var patch: Dictionary = patch_v
		var target: Dictionary = docs[str(patch["file"])]
		_apply(target, str(patch["path"]), patch.get("set"), patch.has("delete"))
	var balance: Dictionary = docs["vertical_slice_balance.json"]
	var waves: Dictionary = docs["waves.json"]
	var tokens: Dictionary = docs["visual_tokens.json"]
	var ext: Dictionary = docs["content_ext.json"]
	var arena: Dictionary = docs["arena.json"]
	var res: ContentLoadResult = ContentLoader.build(balance, waves, tokens, ext, arena, baseline_strings())
	f.errors = res.errors
	f.stage = "loader" if not res.errors.is_empty() else ""
	if res.errors.is_empty():
		f.errors = ContentValidator.validate(res.content)
		f.stage = "validator" if not f.errors.is_empty() else ""
	return f


## Every fixture id in the directory (file name without .json).
static func all_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(FIXTURE_DIR):
		if file.ends_with(".json"):
			ids.append(file.trim_suffix(".json"))
	ids.sort()
	return ids


static func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: Dictionary = parsed
	return out


## The four baseline string tables merged, as ContentLoader.load_from_dir does.
static func baseline_strings() -> Dictionary:
	var out: Dictionary = {}
	for file: String in ContentLoader.STRING_FILES:
		out.merge(read_json("%s/strings/%s" % [TestContent.BASELINE_DIR, file]))
	return out


static func _steps(path: String) -> Array:
	var steps: Array = []
	for part: String in path.split("."):
		var br: int = part.find("[")
		if br < 0:
			steps.append(part)
			continue
		steps.append(part.substr(0, br))
		var rest: String = part.substr(br)
		while rest.begins_with("["):
			var close: int = rest.find("]")
			steps.append(rest.substr(1, close - 1).to_int())
			rest = rest.substr(close + 1)
	return steps


static func _apply(root: Dictionary, path: String, value: Variant, delete: bool) -> void:
	var steps: Array = _steps(path)
	var cur: Variant = root
	for i: int in steps.size() - 1:
		cur = cur[steps[i]]
	var last: Variant = steps[steps.size() - 1]
	if delete:
		if typeof(cur) == TYPE_ARRAY:
			var arr: Array = cur
			var idx: int = last
			arr.remove_at(idx)
		else:
			var dict: Dictionary = cur
			dict.erase(last)
		return
	if typeof(value) == TYPE_STRING and value == "$NAN":
		value = NAN
	elif typeof(value) == TYPE_STRING and value == "$INF":
		value = INF
	cur[last] = value
