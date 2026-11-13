class_name SaveTestData
extends RefCounted
## Test helper: sample profile files (tests/fixtures/saves/) and the in-memory paths the Save autoload uses.
## MAIN, TMP, BAK, CORRUPT and NEWER are the files of profile v2; V1_MAIN, V1_TMP and V1_BAK are the files of the build
## before the Archive, which only the migration reads.

const DIR: String = "res://tests/fixtures/saves"
const MAIN: String = "user://profile_v2.json"
const TMP: String = "user://profile_v2.json.tmp"
const BAK: String = "user://profile_v2.json.bak"
const CORRUPT: String = "user://profile_v2.json.corrupt"
const NEWER: String = "user://profile_v2.json.newer"
const V1_MAIN: String = "user://profile_v1.json"
const V1_TMP: String = "user://profile_v1.json.tmp"
const V1_BAK: String = "user://profile_v1.json.bak"


## Text of tests/fixtures/saves/<fixture_name>.json.
static func text(fixture_name: String) -> String:
	return FileAccess.get_file_as_string("%s/%s.json" % [DIR, fixture_name])


## A fresh MemorySaveFs already holding `main_text` as the main profile file.
static func fs_with(main_text: String) -> MemorySaveFs:
	var fs: MemorySaveFs = MemorySaveFs.new()
	fs.files[MAIN] = main_text
	return fs


## A fresh MemorySaveFs holding `v1_text` as the profile file of the build before the Archive.
static func fs_with_v1(v1_text: String) -> MemorySaveFs:
	var fs: MemorySaveFs = MemorySaveFs.new()
	fs.files[V1_MAIN] = v1_text
	return fs


## Points the Save autoload at `fs` and loads. Returns the LoadStatus. The Archive rules read the shipped game data.
static func boot(fs: SaveFs) -> int:
	Save.use_content(null)
	Save.use_fs(fs)
	return Save.load_profile()


## As `boot`, with a frozen ContentSet for the Archive tree, the milestone table and the kits.
static func boot_with(fs: SaveFs, content: ContentSet) -> int:
	Save.use_content(content)
	Save.use_fs(fs)
	return Save.load_profile()


## Leaves the autoload on a clean in-memory profile and the shipped data.
static func reset() -> void:
	boot(MemorySaveFs.new())
