class_name StateHasher
extends RefCounted
## Accumulates little-endian bytes and returns a sha256 hex digest.

var _buf: PackedByteArray = PackedByteArray()
var _n: int = 0


func put_int(v: int) -> void:
	_grow(8)
	_buf.encode_s64(_n, v)
	_n += 8


func put_float(v: float) -> void:
	_grow(8)
	_buf.encode_double(_n, v)
	_n += 8


func put_ints(v: PackedInt32Array) -> void:
	put_int(v.size())
	_grow(4 * v.size())
	for x: int in v:
		_buf.encode_s32(_n, x)
		_n += 4


func put_bytes(v: PackedByteArray) -> void:
	put_int(v.size())
	_grow(v.size())
	for i: int in v.size():
		_buf[_n + i] = v[i]
	_n += v.size()


func put_floats(v: PackedFloat64Array) -> void:
	put_int(v.size())
	_grow(8 * v.size())
	for x: float in v:
		_buf.encode_double(_n, x)
		_n += 8


## sha256 hex over everything put so far.
func finish() -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if _n > 0:
		ctx.update(_buf.slice(0, _n))
	return ctx.finish().hex_encode()


func _grow(extra: int) -> void:
	var need: int = _n + extra
	if need > _buf.size():
		_buf.resize(maxi(need, maxi(256, _buf.size() * 2)))
