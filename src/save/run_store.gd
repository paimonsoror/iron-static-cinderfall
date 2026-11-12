class_name RunStore
extends RefCounted
## The run file on disk (ARCH 7.5, VARIETY_SPEC 13.3): `user://run_v1.json` (+ `.tmp`, `.bak`), written with the same
## crash-safe steps as the profile (write the temp file, verify it by reading it back, keep the previous good file as
## .bak, rename the temp file over the main one). This class only moves a Dictionary to and from JSON text; what the
## document means (build, content hash, snapshot, tail) is decided in the game layer (RunFile).
##
## The text is compact JSON with sorted keys. JSON numbers are doubles and the engine's writer rounds some of them, so
## the game layer puts everything that must come back bit for bit into the document as text (WorldSnapshot). A
## document that `decode` would not accept (no schema_version, no run id) is not written.

const PATH_MAIN: String = "user://run_v1.json"
const PATH_TMP: String = "user://run_v1.json.tmp"
const PATH_BAK: String = "user://run_v1.json.bak"
const MAX_FILE_CHARS: int = 8000000  ## a real run file is under 200 KB; a larger file is treated as damaged


static func encode(doc: Dictionary) -> String:
	return JSON.stringify(doc, "", true, true) + "\n"


## The document, or {} when the text is not a run file (not a JSON object, no schema_version, no run id). Nothing else
## is checked here and nothing in the file is executed or used as a path.
static func decode(text: String) -> Dictionary:
	if text.strip_edges().is_empty() or text.length() > MAX_FILE_CHARS:
		return {}
	var json: JSON = JSON.new()  # the instance API reports errors instead of printing them
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var doc: Dictionary = json.data
	var version: Variant = doc.get("schema_version")
	if typeof(version) != TYPE_FLOAT and typeof(version) != TYPE_INT:
		return {}
	if typeof(doc.get("run_id")) != TYPE_STRING:
		return {}
	return doc


## False leaves the previous main file as it was.
static func save(fs: SaveFs, doc: Dictionary) -> bool:
	var text: String = encode(doc)
	if decode(text).is_empty():
		return false
	if not fs.write(PATH_TMP, text) or fs.read(PATH_TMP) != text:
		fs.remove(PATH_TMP)
		return false
	var kept: bool = false
	if fs.exists(PATH_MAIN) and not decode(fs.read(PATH_MAIN)).is_empty():
		if not fs.rename(PATH_MAIN, PATH_BAK):  # only a good previous file becomes the backup
			fs.remove(PATH_TMP)
			return false
		kept = true
	if not fs.rename(PATH_TMP, PATH_MAIN):
		if kept:
			fs.rename(PATH_BAK, PATH_MAIN)  # put the previous file back; tmp stays for recovery
		return false
	return true


## The newest readable document: the main file; when it is missing the temp file (a crash between the two renames of
## `save`); then the backup, which is an earlier state of the same run. {} when there is none.
static func load(fs: SaveFs) -> Dictionary:
	var order: Array[String] = [PATH_MAIN, PATH_BAK]
	if not fs.exists(PATH_MAIN):
		order[0] = PATH_TMP
	for path: String in order:
		if fs.exists(path):
			var doc: Dictionary = decode(fs.read(path))
			if not doc.is_empty():
				return doc
	return {}


static func exists(fs: SaveFs) -> bool:
	return fs.exists(PATH_MAIN) or fs.exists(PATH_TMP) or fs.exists(PATH_BAK)


## Removes the run file and its siblings (the run ended).
static func clear(fs: SaveFs) -> void:
	for path: String in [PATH_MAIN, PATH_TMP, PATH_BAK]:
		if fs.exists(path):
			fs.remove(path)
