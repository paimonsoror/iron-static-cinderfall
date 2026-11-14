class_name VfxPool
extends RefCounted
## A fixed-size pool of one effect drawn as ONE transform-only MultiMeshInstance3D (one draw call, no per-instance
## data; ARCH 8). Slots are recycled in a ring, so when the pool is full the OLDEST visual is dropped (ARCH 13).
## Fade is done by scaling over the lifetime (no per-instance alpha). Modes:
##   FLAT      ground ring or disc at p, uniform scale s0 -> s1 (spin = yaw)
##   BILLBOARD like FLAT but turned to face the camera (`facing`)
##   SEGMENT   a bolt from p to v (tracer): head runs out, tail follows, width s0 -> s1
##   DEBRIS    a cube flying ballistically from p with velocity v, scale s0 -> s1, bouncing nowhere (lands and rests)
##   STREAK    a spark: ballistic like DEBRIS but stretched along its velocity, length s0 -> s1
## V4-X modes:
##   STRIP     a flat rectangle for lanes and edge bands: half-length `vel_or_end.x`, half-width s0 -> s1, yaw = spin
##   BEAM      a ribbon from p to v over its WHOLE length (a beam, unlike the SEGMENT tracer that runs out), width s0 -> s1
##   LOB       a billboard flying from p to v on an arc `spin` meters high, size s0 -> s1 (mortar shells, spitter bolts); with
##             `streak_len` > 0 it is a ribbon of that length along the flight, size s0 -> s1 wide (the hornets of the rack)
##   DRIFT     a billboard that moves from p with velocity v and no gravity (embers), size s0 -> s1

enum Mode { FLAT, BILLBOARD, SEGMENT, DEBRIS, STREAK, STRIP, BEAM, LOB, DRIFT }

const GRAVITY: float = 9.8

var node: MultiMeshInstance3D
var capacity: int = 0  ## slots allocated at setup (never changes)
var limit: int = 0  ## slots in use: `capacity` unless a tier limits the pool (`set_limit`); 0 draws nothing
var mode: int = Mode.FLAT
var facing: Basis = Basis.IDENTITY  ## BILLBOARD orientation (camera basis turned to face it)
var streak_width: float = 0.08
var streak_len: float = 0.0  ## LOB only: 0 draws a billboard ball, more draws a ribbon this long, pointing along the flight

var _mm: MultiMesh
var _live: PackedByteArray = PackedByteArray()
var _fresh: PackedByteArray = PackedByteArray()  ## 1 until the first draw: a new effect is always drawn once at age 0
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _s0: PackedFloat32Array = PackedFloat32Array()
var _s1: PackedFloat32Array = PackedFloat32Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _p: PackedVector3Array = PackedVector3Array()
var _v: PackedVector3Array = PackedVector3Array()
var _cursor: int = 0
var _count: int = 0


func setup(parent: Node3D, node_name: String, mesh_res: Mesh, cap: int, pool_mode: int, bounds: AABB) -> void:
	capacity = cap
	limit = cap
	mode = pool_mode
	_live.resize(cap)
	_fresh.resize(cap)
	_age.resize(cap)
	_life.resize(cap)
	_s0.resize(cap)
	_s1.resize(cap)
	_spin.resize(cap)
	_p.resize(cap)
	_v.resize(cap)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = false
	_mm.use_custom_data = false
	_mm.mesh = mesh_res
	_mm.instance_count = cap
	_mm.visible_instance_count = 0
	node = MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = _mm
	node.custom_aabb = bounds
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


## Starts one effect. `vel_or_end` is the velocity (DEBRIS, STREAK), the end point (SEGMENT) or unused.
## Returns the slot; when every slot is live the oldest one is overwritten. -1 when the pool is limited to nothing (`limit` 0).
func spawn(pos: Vector3, vel_or_end: Vector3, size_start: float, size_end: float, life: float, spin: float = 0.0) -> int:
	if limit <= 0:
		return -1
	var i: int = _cursor
	_cursor = (_cursor + 1) % limit
	if _live[i] == 0:
		_count += 1
	_live[i] = 1
	_fresh[i] = 1
	_age[i] = 0.0
	_life[i] = maxf(life, 0.001)
	_s0[i] = size_start
	_s1[i] = size_end
	_spin[i] = spin
	_p[i] = pos
	_v[i] = vel_or_end
	return i


## Advances every live effect by `delta` seconds and rewrites the visible instances.
func step(delta: float) -> void:
	if _count == 0:
		if _mm.visible_instance_count != 0:
			_mm.visible_instance_count = 0
		return
	var out: int = 0
	for i: int in capacity:
		if _live[i] == 0:
			continue
		if _fresh[i] == 1:
			_fresh[i] = 0  # drawn once at age 0 before it starts to age, so even a slow frame shows it
		else:
			_age[i] += delta
		if _age[i] >= _life[i]:
			_live[i] = 0
			_count -= 1
			continue
		_mm.set_instance_transform(out, _transform(i))
		out += 1
	_mm.visible_instance_count = out


func live_count() -> int:
	return _count


## Moves the two end points of a live slot (a beam that follows its shooter and target) and keeps it from aging out for `life` more seconds.
## `size` >= 0 also sets the size (the width of a beam) for the rest of its life.
func retarget(slot: int, pos: Vector3, vel_or_end: Vector3, life: float, size: float = -1.0) -> void:
	if slot < 0 or slot >= capacity or _live[slot] == 0:
		return
	_p[slot] = pos
	_v[slot] = vel_or_end
	_age[slot] = 0.0
	_life[slot] = maxf(life, 0.001)
	if size >= 0.0:
		_s0[slot] = size
		_s1[slot] = size


## Ends a live slot at once.
func release(slot: int) -> void:
	if slot < 0 or slot >= capacity or _live[slot] == 0:
		return
	_live[slot] = 0
	_count -= 1


func is_live(slot: int) -> bool:
	return slot >= 0 and slot < capacity and _live[slot] == 1


## Limits the pool to its first `n` slots (a quality tier: VARIETY_SPEC 10.3). Nothing is allocated: the slots beyond the limit are
## stopped and never used again until the limit is raised. `n` is clamped to 0..capacity.
func set_limit(n: int) -> void:
	limit = clampi(n, 0, capacity)
	for i: int in range(limit, capacity):
		if _live[i] == 1:
			_live[i] = 0
			_count -= 1
	if _cursor >= maxi(limit, 1):
		_cursor = 0


func clear() -> void:
	_live.fill(0)
	_fresh.fill(0)
	_count = 0
	_cursor = 0
	_mm.visible_instance_count = 0


func set_visible(on: bool) -> void:
	node.visible = on


## Alpha of the first surface of the mesh in use (flash brightness; tests).
func mesh_alpha() -> float:
	var m: StandardMaterial3D = _mm.mesh.surface_get_material(0) as StandardMaterial3D
	return m.albedo_color.a


## Swaps the mesh drawn by every instance (Reduced Flash uses a dimmer copy of the same shape).
func set_mesh(mesh_res: Mesh) -> void:
	_mm.mesh = mesh_res


## Where and how a live slot is drawn right now (the MultiMesh itself is write-only in a headless run).
func slot_transform(slot: int) -> Transform3D:
	if slot < 0 or slot >= capacity or _live[slot] == 0:
		return Transform3D.IDENTITY
	return _transform(slot)


## 0..1 age of a live slot (for tests); -1 when the slot is free.
func progress(slot: int) -> float:
	if slot < 0 or slot >= capacity or _live[slot] == 0:
		return -1.0
	return _age[slot] / _life[slot]


func _transform(i: int) -> Transform3D:
	var t01: float = _age[i] / _life[i]
	var s: float = lerpf(_s0[i], _s1[i], t01)
	match mode:
		Mode.FLAT:
			var flat: Basis = Basis(Vector3.UP, _spin[i]) * Basis.from_scale(Vector3(s, 1.0, s))
			return Transform3D(flat, _p[i])
		Mode.BILLBOARD:
			var bb: Basis = facing * Basis(Vector3.UP, _spin[i]) * Basis.from_scale(Vector3(s, 1.0, s))
			return Transform3D(bb, _p[i])
		Mode.SEGMENT:
			return _segment(i, t01, s)
		Mode.DEBRIS:
			var pos: Vector3 = _ballistic(i)
			var spin_basis: Basis = Basis(Vector3.UP, _spin[i] * _age[i]) * Basis(Vector3.RIGHT, 0.5)
			return Transform3D(spin_basis * Basis.from_scale(Vector3.ONE * s), pos)
		Mode.STRIP:
			var strip: Basis = Basis(Vector3.UP, _spin[i]) * Basis.from_scale(Vector3(_v[i].x, 1.0, s))
			return Transform3D(strip, _p[i])
		Mode.BEAM:
			return along(_p[i], _v[i], s)
		Mode.LOB:
			var fly: Vector3 = _lob_at(i, t01)
			if streak_len > 0.0:
				var dir: Vector3 = _lob_at(i, minf(t01 + 0.05, 1.0)) - _lob_at(i, maxf(t01 - 0.05, 0.0))
				dir = dir.normalized() if dir.length() > 0.001 else (_v[i] - _p[i]).normalized()
				return along(fly - dir * streak_len * 0.5, fly + dir * streak_len * 0.5, s)
			return Transform3D(facing * Basis.from_scale(Vector3(s, 1.0, s)), fly)
		Mode.DRIFT:
			return Transform3D(facing * Basis.from_scale(Vector3(s, 1.0, s)), _p[i] + _v[i] * _age[i])
		_:
			return _streak(i, s)


## Where a lob is at `t01` of its flight: the straight line from p to v plus the arc.
func _lob_at(i: int, t01: float) -> Vector3:
	return _p[i].lerp(_v[i], t01) + Vector3(0.0, _spin[i] * 4.0 * t01 * (1.0 - t01), 0.0)


func _segment(i: int, t01: float, width: float) -> Transform3D:
	var a: Vector3 = _p[i]
	var b: Vector3 = _v[i]
	var head: Vector3 = a.lerp(b, clampf(0.6 + t01 * 2.0, 0.0, 1.0))
	var tail: Vector3 = a.lerp(b, clampf((t01 - 0.2) / 0.8, 0.0, 1.0))
	return along(tail, head, width)


func _streak(i: int, length: float) -> Transform3D:
	var pos: Vector3 = _ballistic(i)
	var vel: Vector3 = _v[i] + Vector3(0.0, -GRAVITY * _age[i], 0.0)
	var dir: Vector3 = vel.normalized()
	if vel.length() < 0.01:
		dir = Vector3.RIGHT
	return along(pos - dir * length * 0.5, pos + dir * length * 0.5, streak_width)


## Ballistic position of slot i; rests on the ground once it lands.
func _ballistic(i: int) -> Vector3:
	var p0: Vector3 = _p[i]
	var v0: Vector3 = _v[i]
	var floor_y: float = 0.04
	var land: float = _age[i]
	var disc: float = v0.y * v0.y + 2.0 * GRAVITY * maxf(p0.y - floor_y, 0.0)
	var t_land: float = (v0.y + sqrt(disc)) / GRAVITY
	if t_land < land:
		land = t_land
	var pos: Vector3 = p0 + Vector3(v0.x * land, v0.y * land - 0.5 * GRAVITY * land * land, v0.z * land)
	pos.y = maxf(pos.y, floor_y)
	return pos


## A flat quad stretched from `a` to `b` with `width`, lying in the plane that contains the direction and +Y.
static func along(a: Vector3, b: Vector3, width: float) -> Transform3D:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.001:
		return Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), a)
	var z_axis: Vector3 = d / length
	var x_axis: Vector3 = Vector3.UP.cross(z_axis)
	if x_axis.length() < 0.001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis)
	var basis_out: Basis = Basis(x_axis * width, y_axis, z_axis * length)
	return Transform3D(basis_out, (a + b) * 0.5)
