class_name DrumView
extends Node3D
## The fuel drums of the hazard (GDD 7b `fuel_drums`, SPEC 13.6; V4-X). A drum is a squat red barrel with an amber hazard band (64 triangles, 80 at
## most, no emission: nothing but optics glows on the CHORUS side and nothing here is theirs). The yard has six fixed drum points
## (`arena.drum_points`); at each act start the sim places three of them (`HazardState.d_point`, `d_alive`) and a drum that ignites stops being
## alive; the view only reads those arrays, so it can never show a drum the sim does not have. ONE transform-only MultiMesh (`MAX` instances,
## one draw call per surface), refilled every frame with the living drums. A drum does not block movement or shots (it is only a picture), and
## the blast of one is the ordinary `area_blast` of kind DRUM that `FxBlasts` draws. Drums are placed per act, so they are the same on every tier.

const MAX: int = 6
const RADIUS_M: float = 0.38
const HEIGHT_M: float = 0.9

var node: MultiMeshInstance3D

var _mm: MultiMesh
var _points: PackedVector2Array = PackedVector2Array()
var _shown: int = 0
var _at: PackedVector3Array = PackedVector3Array()


func setup(arena: ArenaDef, bounds: AABB) -> void:
	name = "Drums"
	_points = arena.drum_points
	_at.resize(MAX)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = false
	_mm.use_custom_data = false
	_mm.mesh = _mesh()
	_mm.instance_count = MAX
	_mm.visible_instance_count = 0
	node = MultiMeshInstance3D.new()
	node.name = "DrumInstances"
	node.multimesh = _mm
	node.custom_aabb = bounds
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## Once per rendered frame: one instance per living drum of the sim.
func refresh(sim: SimWorld) -> void:
	var n: int = 0
	if sim != null:
		var h: HazardState = sim.hazards
		for k: int in mini(h.d_point.size(), h.d_alive.size()):
			var p: int = h.d_point[k]
			if h.d_alive[k] == 0 or p < 0 or p >= _points.size() or n >= MAX:
				continue
			_at[n] = Vector3(_points[p].x, 0.0, _points[p].y)
			_mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, float(p) * 0.9), _at[n]))
			n += 1
	_shown = n
	_mm.visible_instance_count = n


func clear() -> void:
	_shown = 0
	_mm.visible_instance_count = 0


func drum_count() -> int:
	return _shown


## Where drum `i` of this frame stands (x, 0, z).
func drum_position(i: int) -> Vector3:
	return _at[i] if i >= 0 and i < _shown else Vector3.INF


func _mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.cylinder(RADIUS_M, RADIUS_M, HEIGHT_M, 8, Transform3D(Basis.IDENTITY, Vector3(0.0, HEIGHT_M * 0.5, 0.0)), &"steel_red")
	mb.cylinder(RADIUS_M + 0.015, RADIUS_M + 0.015, 0.14, 8, Transform3D(Basis.IDENTITY, Vector3(0.0, HEIGHT_M * 0.5, 0.0)), &"hazard")
	return mb.build()
