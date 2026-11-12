extends Node
## `Content` autoload: loads res://data at boot and exposes the typed ContentSet (ARCH 5.4).

const DATA_DIR: String = "res://data"

var db: ContentSet  ## valid after _ready; never null in a running game (named db: `set` is an Object method)
var load_errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload()


## Re-reads res://data. True on success. Logs `content ok ...` or `ERROR: Content: <message>` per problem.
func reload() -> bool:
	var res: ContentLoadResult = ContentLoader.load_from_dir(DATA_DIR)
	var errors: PackedStringArray = res.errors.duplicate()
	if errors.is_empty():
		errors.append_array(ContentValidator.validate(res.content))
	load_errors = errors
	if not errors.is_empty():
		for e: String in errors:
			Log.error("Content", e)
		return false
	db = res.content
	var wave_count: int = db.run.waves.size() if db.run != null else db.waves.size()
	Log.info("Content", "content ok enemies=%d waves=%d directives=%d hash=%s" % [
		db.enemies.size(), wave_count, db.directives.size(), _raw_hash()])
	return true


## First 12 hex chars of the sha256 over the raw data files.
func _raw_hash() -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var files: PackedStringArray = PackedStringArray()
	for f: String in ContentLoader.FILES:
		files.append(DATA_DIR + "/" + f)
	for f: String in VarietyLoader.FILES:
		files.append(DATA_DIR + "/" + f)
	for f: String in ContentLoader.STRING_FILES + ContentLoader.VARIETY_STRING_FILES:
		files.append(DATA_DIR + "/strings/" + f)
	for path: String in files:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 12)
