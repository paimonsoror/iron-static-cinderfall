class_name SimRng
extends RefCounted
## Named, independently seeded random streams (ARCH 6.1). Adding a stream never disturbs the others.

var _seed: int = 0
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(run_seed: int) -> void:
	_seed = run_seed


## Created on first use, seeded from hash(run_seed, name).
func stream(name: StringName) -> RandomNumberGenerator:
	if _streams.has(name):
		return _streams[name]
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = ("%d|%s" % [_seed, String(name)]).hash()
	_streams[name] = r
	return r


## Stream names as text, sorted by text. (Sorting StringNames themselves compares their interned pointers: an order
## that differs from process to process, and inside one process once a name such as "draft:3" was freed and made
## again. A hash in that order made a resumed run fail the hash check of its own run file; V3-I.)
func names_sorted() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for n: StringName in _streams:
		names.append(String(n))
	names.sort()
	return names


func hash_into(h: StateHasher) -> void:
	var names: PackedStringArray = names_sorted()
	h.put_int(names.size())
	for n: String in names:
		h.put_int(n.hash())
		h.put_int(_streams[StringName(n)].state)
