class_name MemorySaveFs
extends SaveFs
## In-memory file system for tests. Failure switches let tests prove that a bad write leaves the previous file
## intact: `fail_writes` makes write() return false, `truncate_writes` stores half the text and still reports
## success (a torn write), `fail_rename_from` makes rename() fail when it starts from that path.

var files: Dictionary = {}
var fail_writes: bool = false
var truncate_writes: bool = false
var fail_rename_from: String = ""


func read(path: String) -> String:
	if files.has(path):
		return str(files[path])
	return ""


func write(path: String, text: String) -> bool:
	if fail_writes:
		return false
	files[path] = text.substr(0, floori(float(text.length()) / 2.0)) if truncate_writes else text
	return true


func exists(path: String) -> bool:
	return files.has(path)


func rename(from: String, to: String) -> bool:
	if not files.has(from) or from == fail_rename_from:
		return false
	files[to] = files[from]
	files.erase(from)
	return true


func remove(path: String) -> bool:
	return files.erase(path)
