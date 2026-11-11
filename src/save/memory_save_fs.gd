class_name MemorySaveFs
extends SaveFs
## In-memory file system for tests. `fail_writes` makes write() return false (a failed write must leave the
## previous file intact).

var files: Dictionary = {}
var fail_writes: bool = false


func read(path: String) -> String:
	if files.has(path):
		return str(files[path])
	return ""


func write(path: String, text: String) -> bool:
	if fail_writes:
		return false
	files[path] = text
	return true


func exists(path: String) -> bool:
	return files.has(path)


func rename(from: String, to: String) -> bool:
	if not files.has(from):
		return false
	files[to] = files[from]
	files.erase(from)
	return true


func remove(path: String) -> bool:
	return files.erase(path)
