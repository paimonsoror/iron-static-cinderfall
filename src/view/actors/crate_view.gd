class_name CrateView
extends Node3D
## The salvage crate and its progress ring (VARIETY_SPEC 3.4, 11.3): one 200 triangle prop that lands on a drop point and a ring
## on the ground at the contest radius that fills while no bodied enemy stands within it. Cyan is ours (crate, ring, flare); the
## ring turns red while the secure timer stalls, i.e. while an enemy is contesting it. Read only: the state is
## `sim.salvage` (`crate_active`, `crate_x`, `crate_z`, `crate_progress`, `crate_life_left`) and the content gives the secure
## time and the radius; `crate_dropped` only starts the landing drop. The ring is a transform-only MultiMesh of SEGMENTS arc
## pieces whose `visible_instance_count` is the progress (no per-frame allocation, one draw call) over one dim full ring.
## Nothing is created after `setup`; the node tree is Crate / Body, RingBack, RingFill.

const SEGMENTS: int = 32
const FALL_HEIGHT: float = 7.0
const FALL_S: float = 0.35
const RING_Y: float = 0.06
const RING_BACK_DIM: float = 0.35
const LOW_LIFE_TICKS: int = 480

var _sim: SimWorld
var _body: MeshInstance3D
var _ring_back: MeshInstance3D
var _ring_fill: MultiMeshInstance3D
var _fill_mm: MultiMesh
var _secure_ticks: int = 0
var _radius: float = 2.0
var _fall_t: float = FALL_S
var _last_progress: int = 0
var _last_tick: int = -1
var _contested: bool = false
var _fraction: float = 0.0
var _look: int = LookDevStyle.Look.CURRENT
var _tier: int = VisualQuality.Tier.HIGH
var _at: Vector3 = Vector3.ZERO
var _was_active: bool = false


func setup(content: ContentSet) -> void:
	name = "Crate"
	visible = false
	if content.run != null:
		_secure_ticks = content.run.salvage_secure_ticks
		_radius = maxf(content.run.salvage_contest_radius_m, 0.5)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = ActorMeshes.crate()
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	_ring_back = MeshInstance3D.new()
	_ring_back.name = "RingBack"
	_ring_back.mesh = VfxMeshes.ring(0.93, 48, &"add_cyan", &"add_cyan", RING_BACK_DIM)
	_ring_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_back.scale = Vector3(_radius, 1.0, _radius)
	_ring_back.position = Vector3(0.0, RING_Y, 0.0)
	add_child(_ring_back)
	_fill_mm = MultiMesh.new()
	_fill_mm.transform_format = MultiMesh.TRANSFORM_3D
	_fill_mm.use_colors = false
	_fill_mm.use_custom_data = false
	_fill_mm.mesh = _segment_mesh()
	_fill_mm.instance_count = SEGMENTS
	for k: int in SEGMENTS:  # fixed transforms: the progress only changes how many are drawn
		var basis: Basis = Basis(Vector3.UP, -TAU * float(k) / float(SEGMENTS)) * Basis.from_scale(Vector3(_radius, 1.0, _radius))
		_fill_mm.set_instance_transform(k, Transform3D(basis, Vector3.ZERO))
	_fill_mm.visible_instance_count = 0
	_ring_fill = MultiMeshInstance3D.new()
	_ring_fill.name = "RingFill"
	_ring_fill.multimesh = _fill_mm
	_ring_fill.custom_aabb = AABB(Vector3(-_radius - 1.0, -1.0, -_radius - 1.0), Vector3(_radius * 2.0 + 2.0, 4.0, _radius * 2.0 + 2.0))
	_ring_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_fill.position = Vector3(0.0, RING_Y + 0.01, 0.0)
	_ring_fill.material_override = VfxMeshes.material(&"add_cyan")
	add_child(_ring_fill)
	apply_look(LookDevStyle.current(), _tier)


## The crate prop: a dark gunmetal body with a darker lid, two pale cargo straps over it, a cyan beacon on the lid, an antenna and a
## cyan strip on the front. About 170 triangles, three surfaces (gunmetal, ceramic, emit_cyan), vertex colours baked like the other props.
static func mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = Color(0.5, 0.52, 0.54, 1.0)
	LookDevShapes.bevel_box(mb, Vector3(0.9, 0.5, 0.6), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.25, 0.0)), &"gunmetal", 0.045)
	mb.tint = Color(0.3, 0.31, 0.33, 1.0)
	LookDevShapes.bevel_box(mb, Vector3(0.84, 0.05, 0.54), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.525, 0.0)), &"gunmetal", 0.02, Vector2.ONE, 0.0, true, true)
	mb.tint = LookActorsKit.plate(0.82)
	for x: float in [-0.27, 0.27]:
		LookDevShapes.bevel_box(mb, Vector3(0.1, 0.54, 0.64), Transform3D(Basis.IDENTITY, Vector3(x, 0.27, 0.0)), &"ceramic", 0.02, Vector2.ONE, 0.0, true, true)
	mb.tint = Color(0.32, 0.32, 0.32, 1.0)  # a short antenna
	LookDevShapes.limb(mb, Vector3(0.0, 0.55, 0.2), Vector3(0.0, 0.84, 0.2), 0.016, 0.011, 4, &"gunmetal", Transform3D.IDENTITY, 0, false, true)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	mb.box(Vector3(0.16, 0.06, 0.16), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.58, -0.08)), &"emit_cyan")
	mb.box(Vector3(0.36, 0.05, 0.014), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.36, -0.306)), &"emit_cyan")
	LookDevBake.ao(mb, 0.75, 0.08, 0.25, 0.0, 0.6, 0.1, [&"emit_cyan"])
	return mb.build()


## Starts reading `sim` (read only) and listening to the crate events.
func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim
	_was_active = false
	_last_tick = -1
	Events.crate_dropped.connect(_on_dropped)


func unbind() -> void:
	if Events.crate_dropped.is_connected(_on_dropped):
		Events.crate_dropped.disconnect(_on_dropped)
	_sim = null
	visible = false
	_was_active = false
	_fill_mm.visible_instance_count = 0


## Once per frame: shows the crate while the sim has one on the field, drops it in on landing, and fills the ring.
func render(delta: float) -> void:
	if _sim == null:
		return
	var s: SalvageState = _sim.salvage
	if not s.crate_active:
		visible = false
		_was_active = false
		return
	if not _was_active:
		_was_active = true
		_at = Vector3(s.crate_x, 0.0, s.crate_z)
		position = _at
		_last_progress = s.crate_progress
		_last_tick = _sim.tick
		_contested = false
	_fall_t = minf(_fall_t + delta, FALL_S)
	var drop: float = 1.0 - _fall_t / FALL_S
	_body.position = Vector3(0.0, FALL_HEIGHT * drop * drop, 0.0)
	visible = true
	if _sim.tick != _last_tick:
		_contested = s.crate_progress <= _last_progress and _secure_ticks > 0 and s.crate_progress < _secure_ticks
		_last_progress = s.crate_progress
		_last_tick = _sim.tick
	_fraction = clampf(float(s.crate_progress) / float(maxi(_secure_ticks, 1)), 0.0, 1.0)
	_fill_mm.visible_instance_count = roundi(_fraction * float(SEGMENTS))
	_ring_fill.material_override = VfxMeshes.material(&"add_red" if _contested else &"add_cyan")


## Dresses the prop for a look and tier (the shared hard-surface materials; the plain palette in CURRENT).
func apply_look(new_look: int, new_tier: int) -> void:
	_look = new_look
	_tier = new_tier
	var m: ArrayMesh = _body.mesh as ArrayMesh
	for s: int in m.get_surface_count():
		var role: StringName = StringName(m.surface_get_material(s).resource_name)
		_body.set_surface_override_material(s, null if _look == LookDevStyle.Look.CURRENT else LookDevMat.surface(role, _look, _tier))


## World position of the crate on the ground (INF while there is none).
func crate_position() -> Vector3:
	return _at if visible else Vector3.INF


func is_crate_visible() -> bool:
	return visible


## 0..1 of the secure time the ring shows.
func progress_fraction() -> float:
	return _fraction


func ring_segments() -> int:
	return _fill_mm.visible_instance_count


func is_contested() -> bool:
	return _contested


func radius() -> float:
	return _radius


## True while the crate is still falling in (the landing drop).
func is_falling() -> bool:
	return _fall_t < FALL_S


func _on_dropped(_x: float, _z: float) -> void:
	_fall_t = 0.0


## One arc piece of the ring at unit radius, from angle 0 to a segment's width minus a small gap: a flat band between 0.9 and 1.0.
static func _segment_mesh() -> ArrayMesh:
	var b: VfxMeshes.Builder = VfxMeshes.Builder.new()
	var span: float = TAU / float(SEGMENTS) * 0.86
	var d0: Vector3 = Vector3(cos(0.0), 0.0, sin(0.0))
	var d1: Vector3 = Vector3(cos(span), 0.0, sin(span))
	b.tri(0, d0 * 0.9, d0 * 1.0, d1 * 1.0)
	b.tri(0, d0 * 0.9, d1 * 1.0, d1 * 0.9)
	return b.build([&"add_cyan"], 1.0)
