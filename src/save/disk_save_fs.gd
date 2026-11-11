class_name DiskSaveFs
extends SaveFs
## user:// file system. Windows cannot rename over an existing file, so rename removes the target first (only
## after checking that the source exists, so a bad call never deletes the target for nothing).


func read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func write(path: String, text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var stored: bool = f.store_string(text)
	var failed: bool = f.get_error() != OK
	f.close()
	return stored and not failed


func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func rename(from: String, to: String) -> bool:
	if not FileAccess.file_exists(from):
		return false
	var dest: String = ProjectSettings.globalize_path(to)
	if FileAccess.file_exists(to) and DirAccess.remove_absolute(dest) != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), dest) == OK


func remove(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
