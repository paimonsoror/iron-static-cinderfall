class_name IntegrationCountingFs
extends MemorySaveFs
## Test helper (W3-A): a MemorySaveFs that counts how often the profile file was replaced (renamed over the main
## path), so a test can prove that a finished run writes the profile exactly once.

var main_replacements: int = 0
var tmp_writes: int = 0


func write(path: String, text: String) -> bool:
	if path == Save.PATH_TMP:
		tmp_writes += 1
	return super.write(path, text)


func rename(from: String, to: String) -> bool:
	var ok: bool = super.rename(from, to)
	if ok and to == Save.PATH_MAIN:
		main_replacements += 1
	return ok


## The profile as stored under the main path, or null.
func stored_profile() -> Profile:
	return ProfileCodec.decode(read(Save.PATH_MAIN)).profile


## The profile as stored under the backup path, or null.
func backup_profile() -> Profile:
	return ProfileCodec.decode(read(Save.PATH_BAK)).profile
