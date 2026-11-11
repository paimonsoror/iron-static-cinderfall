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


func hash_into(h: StateHasher) -> void:
	var names: Array = _streams.keys()
	names.sort()
	h.put_int(names.size())
	for n: StringName in names:
		h.put_int(String(n).hash())
		h.put_int(_streams[n].state)
