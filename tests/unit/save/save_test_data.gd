class_name SaveTestData
extends RefCounted
## Test helper: sample profile files (tests/fixtures/saves/) and the in-memory paths the Save autoload uses.

const DIR: String = "res://tests/fixtures/saves"
const MAIN: String = "user://profile_v1.json"
const TMP: String = "user://profile_v1.json.tmp"
const BAK: String = "user://profile_v1.json.bak"
const CORRUPT: String = "user://profile_v1.json.corrupt"
const NEWER: String = "user://profile_v1.json.newer"


## Text of tests/fixtures/saves/<fixture_name>.json.
static func text(fixture_name: String) -> String:
	return FileAccess.get_file_as_string("%s/%s.json" % [DIR, fixture_name])


## A fresh MemorySaveFs already holding `main_text` as the main profile file.
static func fs_with(main_text: String) -> MemorySaveFs:
	var fs: MemorySaveFs = MemorySaveFs.new()
	fs.files[MAIN] = main_text
	return fs


## Points the Save autoload at `fs` and loads. Returns the LoadStatus.
static func boot(fs: SaveFs) -> int:
	Save.use_fs(fs)
	return Save.load_profile()
