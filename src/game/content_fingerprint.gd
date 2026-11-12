class_name ContentFingerprint
extends RefCounted
## The `content_hash` of the run file (VARIETY_SPEC 13.3): 12 hex characters over everything in a ContentSet that can
## change what a run does. A run file made with other content cannot be resumed (the replay would diverge), so it is
## closed instead. The hash walks the def objects themselves, so it is the same for `Content.db`, for a fixture and
## for a set a test has changed in memory. Texts (`strings`) and the visual tokens are left out: they never reach
## the sim, and a wording fix must not end a run.

const SKIP: PackedStringArray = ["strings", "tokens"]
const MAX_DEPTH: int = 12
const LENGTH: int = 12


static func of(content: ContentSet) -> String:
	if content == null:
		return ""
	var h: StateHasher = StateHasher.new()
	_put_object(h, content, SKIP, 0)
	return h.finish().substr(0, LENGTH)


static func _put_object(h: StateHasher, o: Object, skip: PackedStringArray, depth: int) -> void:
	if o == null or depth > MAX_DEPTH:
		h.put_int(0)
		return
	for p: Dictionary in o.get_property_list():
		var usage: int = p["usage"]
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var field: String = p["name"]
		if skip.has(field):
			continue
		_put_text(h, field)
		_put(h, o.get(field), depth + 1)


static func _put(h: StateHasher, v: Variant, depth: int) -> void:
	var type: int = typeof(v)
	h.put_int(type)
	match type:
		TYPE_NIL:
			pass
		TYPE_BOOL:
			var b: bool = v
			h.put_int(1 if b else 0)
		TYPE_INT:
			var i: int = v
			h.put_int(i)
		TYPE_FLOAT:
			var f: float = v
			h.put_float(f)
		TYPE_VECTOR2:
			var v2: Vector2 = v
			h.put_float(v2.x)
			h.put_float(v2.y)
		TYPE_ARRAY:
			var list: Array = v
			h.put_int(list.size())
			for item: Variant in list:
				_put(h, item, depth + 1)
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var keys: Array = d.keys()
			keys.sort_custom(_by_text)
			h.put_int(keys.size())
			for key: Variant in keys:
				_put_text(h, str(key))
				_put(h, d[key], depth + 1)
		TYPE_OBJECT:
			var o: Object = v
			_put_object(h, o, PackedStringArray(), depth)
		_:
			_put_text(h, var_to_str(v))  # strings, string names, packed arrays, colors: the text form is stable


static func _by_text(a: Variant, b: Variant) -> bool:
	return str(a) < str(b)


static func _put_text(h: StateHasher, text: String) -> void:
	h.put_bytes(text.to_utf8_buffer())
