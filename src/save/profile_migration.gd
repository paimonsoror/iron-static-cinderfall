class_name ProfileMigration
extends RefCounted
## The profile of the build before the Archive (`user://profile_v1.json`, schema 1) as the input of profile v2
## (ARCH 7.5, VARIETY_SPEC 13.3). Read only: the v1 files are never written, moved or deleted here or anywhere
## else, so a downgrade still finds them. The v1 -> v2 field rules live in ProfileCodec.decode (a schema 1 document is
## migrated on the way in); this class only finds the right file.

const PATH_MAIN: String = "user://profile_v1.json"
const PATH_TMP: String = "user://profile_v1.json.tmp"
const PATH_BAK: String = "user://profile_v1.json.bak"

## What `inspect` found.
enum Found {
	NONE,  ## no v1 file at all
	USABLE,  ## a schema 1 profile can be read
	DAMAGED,  ## a v1 file exists and none of them can be read
	NEWER,  ## the v1 file name holds a document of a schema this build does not know
}


## The migrated profile from the first usable v1 file, else null. The order is the one of the v2 files: the main file;
## when it is missing the temp file (a crash between the two renames of a flush) and then the backup; when it is
## unreadable the backup.
static func read(fs: SaveFs) -> Profile:
	var paths: Array[String] = [PATH_MAIN, PATH_BAK]
	if not fs.exists(PATH_MAIN):
		paths = [PATH_TMP, PATH_BAK]
	for path: String in paths:
		if fs.exists(path):
			var decoded: ProfileDecodeResult = ProfileCodec.decode(fs.read(path))
			if decoded.profile != null and decoded.schema_version == 1:
				return decoded.profile
	return null


## Why `read` found nothing (or USABLE when it would).
static func inspect(fs: SaveFs) -> int:
	if read(fs) != null:
		return Found.USABLE
	var found: int = Found.NONE
	for path: String in [PATH_MAIN, PATH_TMP, PATH_BAK]:
		if not fs.exists(path):
			continue
		found = Found.DAMAGED
		if ProfileCodec.decode(fs.read(path)).schema_version > Profile.SCHEMA_VERSION:
			return Found.NEWER
	return found
