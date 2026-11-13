extends GdUnitTestSuite
## The fixture rule (CLAUDE.md, WORK_PLAN 8): `tests/fixtures/data_variety/` is a byte copy of the shipped `data/` and
## `data/strings/`. Unit tests read the fixture, the game reads `data/`; while the two are the same bytes, a green suite
## is a statement about the game that ships. Whoever changes a data or strings file applies the identical change to its
## fixture copy (and re-records the goldens that move); after a merge of two branches the coordinator re-syncs.
## How to fix a failure here: copy the named file from `data/` (or `data/strings/`) over its fixture copy, run the suites,
## re-record what moved.

const DATA_DIR: String = "res://data"
const FIXTURE_DIR: String = "res://tests/fixtures/data_variety"


func _json_files(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".json"):
			out.append(file_name)
	out.sort()
	return out


func _differences(sub_dir: String) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var shipped: PackedStringArray = _json_files(DATA_DIR + sub_dir)
	var frozen: PackedStringArray = _json_files(FIXTURE_DIR + sub_dir)
	for file_name: String in shipped:
		if not frozen.has(file_name):
			problems.append("%s%s/%s has no fixture copy" % [DATA_DIR, sub_dir, file_name])
		elif FileAccess.get_file_as_bytes(DATA_DIR + sub_dir + "/" + file_name) != FileAccess.get_file_as_bytes(FIXTURE_DIR + sub_dir + "/" + file_name):
			problems.append("%s%s/%s differs from its fixture copy" % [DATA_DIR, sub_dir, file_name])
	for file_name: String in frozen:
		if not shipped.has(file_name):
			problems.append("%s%s/%s is not a shipped file" % [FIXTURE_DIR, sub_dir, file_name])
	return problems


func test_every_data_file_equals_its_fixture_copy() -> void:
	assert_int(_json_files(DATA_DIR).size()).is_greater(5)
	assert_str("\n".join(_differences(""))).is_empty()


func test_every_strings_file_equals_its_fixture_copy() -> void:
	assert_int(_json_files(DATA_DIR + "/strings").size()).is_greater(2)
	assert_str("\n".join(_differences("/strings"))).is_empty()


func test_the_fixture_is_the_fifteen_wave_game() -> void:
	var c: ContentSet = TestContent.variety()
	assert_int(c.run.waves.size()).is_equal(15)
	assert_int(c.run.acts.size()).is_equal(3)
	for wave_number: int in [5, 10, 15]:
		assert_int(c.run.wave_slot(wave_number).kind).is_equal(WaveSlotDef.Kind.BOSS)
	for act: int in [1, 2, 3]:
		var pool: int = 0
		for b: BossDef in c.bosses:
			pool += 1 if b.pool_act == act else 0
		assert_int(pool).is_equal(2 if act < 3 else 1)  # CONTENT 5: two bosses per act, then always the Siege Hulk
	assert_int(c.unlocks.size()).is_equal(24)
