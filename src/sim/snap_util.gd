class_name SnapUtil
extends RefCounted
## Field-list helpers for the variety state classes (VARIETY_SPEC 9.5 rule 3, 13.2): one list of property names per
## class drives hash_into, to_dict and from_dict, so a field cannot be hashed but not saved, or saved but not hashed.
## Supported property types: int, bool, float, PackedInt32Array, PackedFloat64Array, PackedByteArray.
## to_dict gives JSON-safe values (arrays of numbers); from_dict accepts what JSON.parse returns (every number a float).


static func hash_fields(h: StateHasher, o: Object, fields: PackedStringArray) -> void:
	for f: String in fields:
		var v: Variant = o.get(f)
		match typeof(v):
			TYPE_INT:
				var i: int = v
				h.put_int(i)
			TYPE_BOOL:
				var b: bool = v
				h.put_int(1 if b else 0)
			TYPE_FLOAT:
				var x: float = v
				h.put_float(x)
			TYPE_PACKED_INT32_ARRAY:
				var ia: PackedInt32Array = v
				h.put_ints(ia)
			TYPE_PACKED_FLOAT64_ARRAY:
				var fa: PackedFloat64Array = v
				h.put_floats(fa)
			TYPE_PACKED_BYTE_ARRAY:
				var ba: PackedByteArray = v
				h.put_bytes(ba)
			_:
				push_error("SnapUtil: field '%s' has an unsupported type" % f)


static func to_dict(o: Object, fields: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for f: String in fields:
		var v: Variant = o.get(f)
		match typeof(v):
			TYPE_PACKED_INT32_ARRAY:
				var ia: PackedInt32Array = v
				out[f] = Array(ia)
			TYPE_PACKED_FLOAT64_ARRAY:
				var fa: PackedFloat64Array = v
				out[f] = Array(fa)
			TYPE_PACKED_BYTE_ARRAY:
				var ba: PackedByteArray = v
				out[f] = Array(ba)
			_:
				out[f] = v
	return out


## Sets every field of `fields` that `d` holds; a missing key keeps the current value.
static func from_dict(o: Object, fields: PackedStringArray, d: Dictionary) -> void:
	for f: String in fields:
		if not d.has(f):
			continue
		var src: Variant = d[f]
		match typeof(o.get(f)):
			TYPE_INT:
				o.set(f, roundi(num(src)))
			TYPE_BOOL:
				o.set(f, typeof(src) == TYPE_BOOL and src == true)
			TYPE_FLOAT:
				o.set(f, num(src))
			TYPE_PACKED_INT32_ARRAY:
				o.set(f, ints(src))
			TYPE_PACKED_FLOAT64_ARRAY:
				o.set(f, floats(src))
			TYPE_PACKED_BYTE_ARRAY:
				o.set(f, PackedByteArray(Array(ints(src))))


static func num(v: Variant) -> float:
	if typeof(v) == TYPE_FLOAT:
		var x: float = v
		return x
	if typeof(v) == TYPE_INT:
		var i: int = v
		return float(i)
	return 0.0


static func ints(v: Variant) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if typeof(v) == TYPE_PACKED_INT32_ARRAY:
		out = v
		return out.duplicate()
	if typeof(v) != TYPE_ARRAY:
		return out
	var list: Array = v
	for item: Variant in list:
		out.append(roundi(num(item)))
	return out


static func floats(v: Variant) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if typeof(v) != TYPE_ARRAY:
		return out
	var list: Array = v
	for item: Variant in list:
		out.append(num(item))
	return out
