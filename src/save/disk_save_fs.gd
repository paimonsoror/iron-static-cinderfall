class_name DiskSaveFs
extends SaveFs
## user:// file system. TODO(W1-D): verify rename-over-existing on Windows.


func read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func write(path: String, text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func rename(from: String, to: String) -> bool:
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(to))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)) == OK


func remove(path: String) -> bool:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
