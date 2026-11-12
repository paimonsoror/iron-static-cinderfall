class_name VarietyBadData
extends RefCounted
## Test helper (V1-S). A bad variety fixture (tests/fixtures/data_bad_variety/<id>.json) is the frozen variety fixture
## plus a list of patches, in the format of BadDataFixture:
##   { "rule": "...", "stage": "loader" | "validator",
##     "patches": [ { "file": "run.json", "path": "packs[0].groups[0].share", "set": 0.5 } ], "expect": [ "<exact error>" ] }
## `file` is any of the five base files or the six variety files. run() goes through the production pipeline:
## ContentLoader.build with the 7th parameter, then ContentValidator.validate when the loader had no errors.

const FIXTURE_DIR: String = "res://tests/fixtures/data_bad_variety"

var rule: String = ""
var expect: PackedStringArray = PackedStringArray()
var expected_stage: String = ""
var errors: PackedStringArray = PackedStringArray()
var stage: String = ""


## The parsed files of the variety fixture: file name -> Dictionary (base and variety files).
static func docs() -> Dictionary:
	var out: Dictionary = {}
	for file: String in ContentLoader.FILES:
		out[file] = BadDataFixture.read_json("%s/%s" % [TestContent.VARIETY_DIR, file])
	for file: String in VarietyLoader.FILES:
		out[file] = BadDataFixture.read_json("%s/%s" % [TestContent.VARIETY_DIR, file])
	return out


static func strings() -> Dictionary:
	var out: Dictionary = {}
	for file: String in ContentLoader.STRING_FILES + ContentLoader.VARIETY_STRING_FILES:
		out.merge(BadDataFixture.read_json("%s/strings/%s" % [TestContent.VARIETY_DIR, file]))
	return out


## Builds content from `all_docs` (see docs()) the way load_from_dir does.
static func build(all_docs: Dictionary) -> ContentLoadResult:
	var variety: Dictionary = {}
	for file: String in VarietyLoader.FILES:
		if all_docs.has(file):
			variety[file] = all_docs[file]
	var balance: Dictionary = all_docs["vertical_slice_balance.json"]
	var waves: Dictionary = all_docs["waves.json"]
	var tokens: Dictionary = all_docs["visual_tokens.json"]
	var ext: Dictionary = all_docs["content_ext.json"]
	var arena: Dictionary = all_docs["arena.json"]
	return ContentLoader.build(balance, waves, tokens, ext, arena, strings(), variety)


static func run(fixture_id: String) -> VarietyBadData:
	var f: VarietyBadData = VarietyBadData.new()
	var spec: Dictionary = BadDataFixture.read_json("%s/%s.json" % [FIXTURE_DIR, fixture_id])
	f.rule = str(spec.get("rule", ""))
	f.expected_stage = str(spec.get("stage", ""))
	var expected: Array = spec.get("expect", [])
	for line: Variant in expected:
		f.expect.append(str(line))
	var all_docs: Dictionary = docs()
	var patches: Array = spec.get("patches", [])
	for patch_v: Variant in patches:
		var patch: Dictionary = patch_v
		var target: Dictionary = all_docs[str(patch["file"])]
		BadDataFixture._apply(target, str(patch["path"]), patch.get("set"), patch.has("delete"))
	var res: ContentLoadResult = build(all_docs)
	f.errors = res.errors
	f.stage = "loader" if not res.errors.is_empty() else ""
	if res.errors.is_empty():
		f.errors = ContentValidator.validate(res.content)
		f.stage = "validator" if not f.errors.is_empty() else ""
	return f


static func all_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(FIXTURE_DIR):
		if file.ends_with(".json"):
			ids.append(file.trim_suffix(".json"))
	ids.sort()
	return ids
