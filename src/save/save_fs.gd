class_name SaveFs
extends RefCounted
## File-system interface for the save system. DiskSaveFs (user://) and MemorySaveFs (tests) implement it.
## Paths are full ("user://profile_v1.json"); text is UTF-8.

@warning_ignore_start("unused_parameter")


## File text, or "" when missing.
func read(path: String) -> String:
	return ""


func write(path: String, text: String) -> bool:
	return false


func exists(path: String) -> bool:
	return false


## DiskSaveFs removes the target first (Windows cannot rename over an existing file).
func rename(from: String, to: String) -> bool:
	return false


func remove(path: String) -> bool:
	return false
