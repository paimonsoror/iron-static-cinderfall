class_name FreightView
extends Node3D
## The freight car of Runaway Freight (GDD 7b, SPEC 7.1, 13.6; V4-X): a dead boxcar (600 triangles at most, dull red and gunmetal, no light:
## it is a hazard, not a creature) that crosses the yard on a rail line in 1.2 s, right to left like the swarm. It is one node, hidden until a
## freight event starts. The lane it runs on is the one the warning showed (`warned` remembers the z of the last freight warning, snapped to the
## nearest rail line); `started` launches it, `step` moves it, and while it runs it throws sparks from its wheels (a steady trickle on HIGH, a thin
## one on MID, none on LOW, through the spark pool of the VfxLayer). The damage is the sim's (700 along the line); this only draws the car and
## its wake. Two freight events can name the car (the player's `freight_call` and the world's `runaway_freight`); a second start within
## GUARD_S of the first is ignored, so one crossing is one car.

const IDS: Array[StringName] = [&"runaway_freight", &"freight_call"]
const DEFAULT_CROSS_S: float = 1.2
const GUARD_S: float = 1.5
const OVERSHOOT_M: float = 9.0  ## the car starts and ends this far outside the yard's edges
const CAR_Y: float = 0.0
const SPARK_EVERY_S: Array[float] = [0.0, 0.07, 0.03]
const MAX_SPARKS_PER_FRAME: int = 4

var car: MeshInstance3D
var sparks: VfxPool  ## set by the VfxLayer; null in tests that build the car alone

var crossings: int = 0  ## cars launched (tests, reports)

var _arena: ArenaDef
var _content: ContentSet
var _lane_z: float = 0.0
var _left: float = 0.0
var _total: float = DEFAULT_CROSS_S
var _guard: float = 0.0
var _spark_cd: float = 0.0
var _rng: RandomNumberGenerator


func setup(content: ContentSet, rng: RandomNumberGenerator) -> void:
	name = "Freight"
	_content = content
	_arena = content.arena
	_rng = rng
	_lane_z = _arena.rail_z[0] if not _arena.rail_z.is_empty() else 0.0
	car = MeshInstance3D.new()
	car.name = "FreightCar"
	car.mesh = _mesh()
	car.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	car.visible = false
	add_child(car)


## `event_warned(id, ticks, x, z)`: remembers the lane of the next car.
func warned(event_id: StringName, _ticks: int, _x: float, z: float) -> void:
	if IDS.has(event_id):
		_lane_z = RailLines.nearest_z(_arena, z)


## `event_started(id)`: the car goes.
func started(event_id: StringName) -> bool:
	if not IDS.has(event_id) or _guard > 0.0:
		return false
	var index: int = _content.event_index(event_id)
	_total = DEFAULT_CROSS_S
	if index >= 0 and _content.events[index].duration_ticks > 0:
		_total = float(_content.events[index].duration_ticks) * SimWorld.DT
	_left = _total
	_guard = GUARD_S
	crossings += 1
	car.visible = true
	_place()
	return true


## Once per rendered frame.
func step(delta: float, tier: int) -> void:
	_guard = maxf(0.0, _guard - delta)
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		car.visible = false
		return
	_place()
	_wake(delta, tier)


func running() -> bool:
	return _left > 0.0


func lane_z() -> float:
	return _lane_z


## Where the car is along its crossing (0 at the right edge, 1 at the left); -1 when it is not running.
func progress() -> float:
	return 1.0 - _left / _total if _left > 0.0 else -1.0


func clear() -> void:
	_left = 0.0
	_guard = 0.0
	car.visible = false


func _place() -> void:
	var t: float = clampf(1.0 - _left / _total, 0.0, 1.0)
	var x: float = lerpf(_arena.max_x + OVERSHOOT_M, _arena.min_x - OVERSHOOT_M, t)
	car.position = Vector3(x, CAR_Y, _lane_z)


func _wake(delta: float, tier: int) -> void:
	var every: float = SPARK_EVERY_S[clampi(tier, 0, 2)]
	if sparks == null or every <= 0.0:
		return
	_spark_cd -= delta
	var made: int = 0
	while _spark_cd <= 0.0 and made < MAX_SPARKS_PER_FRAME:  # a slow frame throws as many as it missed
		_spark_cd += every
		made += 1
		if car.position.x > _arena.max_x or car.position.x < _arena.min_x:
			continue  # the sparks are for the part of the lane that is in the yard
		var vel: Vector3 = Vector3(_rng.randf_range(1.0, 4.0), _rng.randf_range(1.5, 3.5), _rng.randf_range(-2.0, 2.0))
		var side: float = -0.62 if _rng.randf() < 0.5 else 0.62
		var _spark: int = sparks.spawn(Vector3(car.position.x + 2.6, 0.12, _lane_z + side), vel, 0.5, 0.06, _rng.randf_range(0.18, 0.32))
	_spark_cd = maxf(_spark_cd, 0.0)


## A boxcar 6.4 m long on two bogies of two wheels each; roof ribs, door rail and bumpers. About 330 triangles.
func _mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3(6.2, 1.5, 1.7), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.25, 0.0)), &"steel_red")
	mb.box(Vector3(6.4, 0.28, 1.5), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.46, 0.0)), &"dark_frame")
	mb.box(Vector3(6.3, 0.1, 1.8), Transform3D(Basis.IDENTITY, Vector3(0.0, 2.05, 0.0)), &"gunmetal")
	for rib: int in 5:
		mb.box(Vector3(0.08, 0.1, 1.5), Transform3D(Basis.IDENTITY, Vector3(-2.4 + float(rib) * 1.2, 2.14, 0.0)), &"gunmetal")
	mb.box(Vector3(2.0, 0.12, 0.06), Transform3D(Basis.IDENTITY, Vector3(0.4, 1.8, 0.88)), &"gunmetal")
	for end: float in [-1.0, 1.0]:
		mb.box(Vector3(0.22, 0.4, 1.2), Transform3D(Basis.IDENTITY, Vector3(end * 3.3, 0.7, 0.0)), &"hazard")
		for side: float in [-1.0, 1.0]:
			for bogie: float in [-0.55, 0.55]:
				var wheel: Transform3D = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(end * 2.15 + bogie, 0.32, side * 0.7))
				mb.cylinder(0.32, 0.32, 0.14, 8, wheel, &"rubber")
	return mb.build()
