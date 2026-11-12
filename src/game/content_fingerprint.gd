class_name ContentFingerprint
extends RefCounted
## The `content_hash` of the run file (VARIETY_SPEC 13.3): 12 hex characters over everything in a ContentSet that can
## change what a run does. A run file made with other content cannot be resumed (the replay would diverge), so it is
## closed instead. The hash walks the def objects themselves, so it is the same for `Content.db`, for a fixture and
## for a set a test has changed in memory. Texts (`strings`) and the visual tokens are left out: they never reach
## the sim, and a wording fix must not end a run.
##
## The walk writes one token per value into a list and hashes the joined text once (a float is written as its exact
## bit pattern). It runs at the start of every run and when the menu looks at a run file.

const SKIP: PackedStringArray = ["strings", "tokens"]
const MAX_DEPTH: int = 12
const LENGTH: int = 12


static func of(content: ContentSet) -> String:
	if content == null:
		return ""
	var out: PackedStringArray = PackedStringArray()
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(8)
	_put_object(out, buf, content, SKIP, 0)
	return "\n".join(out).sha256_text().substr(0, LENGTH)


static func _put_object(out: PackedStringArray, buf: PackedByteArray, o: Object, skip: PackedStringArray, depth: int) -> void:
	if o == null or depth > MAX_DEPTH:
		out.append("null")
		return
	out.append("{")
	for p: Dictionary in o.get_property_list():
		var usage: int = p["usage"]
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var field: String = p["name"]
		if skip.has(field):
			continue
		out.append(field)
		_put(out, buf, o.get(field), depth + 1)
	out.append("}")


static func _put(out: PackedStringArray, buf: PackedByteArray, v: Variant, depth: int) -> void:
	match typeof(v):
		TYPE_NIL:
			out.append("nil")
		TYPE_FLOAT:
			var f: float = v
			buf.encode_double(0, f)
			out.append("f%d" % buf.decode_s64(0))
		TYPE_ARRAY:
			var list: Array = v
			out.append("[%d" % list.size())
			for item: Variant in list:
				_put(out, buf, item, depth + 1)
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var keys: Array = d.keys()
			keys.sort_custom(_by_text)
			out.append("<%d" % keys.size())
			for key: Variant in keys:
				out.append(str(key))
				_put(out, buf, d[key], depth + 1)
		TYPE_OBJECT:
			var o: Object = v
			_put_object(out, buf, o, PackedStringArray(), depth)
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_VECTOR2:
			out.append(var_to_bytes(v).hex_encode())  # exact, where the text form would round
		_:
			out.append("%d:%s" % [typeof(v), str(v)])  # bool, int, strings, string names, packed int and string arrays


static func _by_text(a: Variant, b: Variant) -> bool:
	return str(a) < str(b)
