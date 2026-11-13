class_name FxPools
extends RefCounted
## Burning ground pools (slag, burn; VARIETY_SPEC 10.3 "Ground pools", 12.3 `fx_pool`): a glowing amber disc under every pool the sim
## keeps alive. They hurt enemies, so they are amber with no hatch (5.6 rule 4). `pool_changed(id, x, z, radius, on)` opens a pool (on)
## or closes it (off, by id). One transform-only MultiMesh at the HIGH size (10) limited by tier (`VisualQuality.pool_cap`: 6 / 8 / 10): when more pools
## are alive than the limit the OLDEST is dropped from the view. A pool is persistent, so it is not a VfxPool ring buffer: a slot
## stays until its id closes it. The disc breathes a little (a 5 percent scale pulse). Nothing is allocated after `setup`.

const CAP_HIGH: int = 10
const Y: float = 0.045
const PULSE: float = 0.05

var node: MultiMeshInstance3D

var _mm: MultiMesh
var _live: PackedByteArray = PackedByteArray()
var _id: PackedInt32Array = PackedInt32Array()
var _age: PackedInt32Array = PackedInt32Array()
var _at: PackedVector3Array = PackedVector3Array()  ## x, radius, z
var _limit: int = CAP_HIGH
var _t: float = 0.0
var _clock: int = 0
var _drawn: int = 0


func setup(parent: Node3D, bounds: AABB) -> void:
	_live.resize(CAP_HIGH)
	_id.resize(CAP_HIGH)
	_age.resize(CAP_HIGH)
	_at.resize(CAP_HIGH)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = false
	_mm.use_custom_data = false
	_mm.mesh = MeshKit.begin().disc(1.0, 28, Transform3D.IDENTITY, &"pool_amber").build()
	_mm.instance_count = CAP_HIGH
	_mm.visible_instance_count = 0
	node = MultiMeshInstance3D.new()
	node.name = "GroundPools"
	node.multimesh = _mm
	node.custom_aabb = bounds
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func set_quality(tier: int) -> void:
	_limit = VisualQuality.pool_cap(tier)
	for i: int in range(_limit, CAP_HIGH):
		_live[i] = 0


## A pool opens (`on`, at (x, z) with `radius` meters) or closes (by `pool_id`).
func changed(pool_id: int, x: float, z: float, radius: float, on: bool) -> void:
	var slot: int = -1
	for i: int in _limit:
		if _live[i] == 1 and _id[i] == pool_id:
			slot = i
			break
	if not on:
		if slot >= 0:
			_live[slot] = 0
		return
	if slot < 0:
		slot = _free_or_oldest()
	_live[slot] = 1
	_id[slot] = pool_id
	_age[slot] = _clock
	_clock += 1
	_at[slot] = Vector3(x, radius, z)


## Draws the live pools (call once per frame).
func step(delta: float) -> void:
	_t += delta
	var pulse: float = 1.0 + PULSE * sin(_t * 3.0)
	var out: int = 0
	for i: int in _limit:
		if _live[i] == 0:
			continue
		var r: float = _at[i].y * pulse
		_mm.set_instance_transform(out, Transform3D(Basis.from_scale(Vector3(r, 1.0, r)), Vector3(_at[i].x, Y, _at[i].z)))
		out += 1
	_drawn = out
	_mm.visible_instance_count = out


func live_count() -> int:
	var n: int = 0
	for i: int in _limit:
		n += _live[i]
	return n


func drawn_count() -> int:
	return _drawn


func limit() -> int:
	return _limit


func clear() -> void:
	_live.fill(0)
	_mm.visible_instance_count = 0
	_drawn = 0


func _free_or_oldest() -> int:
	var oldest: int = 0
	for i: int in _limit:
		if _live[i] == 0:
			return i
		if _age[i] < _age[oldest]:
			oldest = i
	return oldest
