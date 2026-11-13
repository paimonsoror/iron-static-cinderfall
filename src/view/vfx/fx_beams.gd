class_name FxBeams
extends RefCounted
## The beams we fire (VARIETY_SPEC 3.5, 10.3 `fx_beam`; V4-X): the cutting torch, a continuous cyan-white ribbon from the Warden's muzzle to
## the enemy it is locked on, that thickens with the ramp (`ArsenalState.beam_hits`) and throws sparks at the contact point; and the rail
## lance, a thin cyan line while it charges (`charge_left`, fixed on `charge_x`, `charge_z`) and a thick white line for 0.12 s when it
## fires, with sparks at every enemy on the line. Both are read from the sim state every frame (the view never asks the sim to do
## anything) and from `shot_fired`. One pooled BEAM MultiMesh of 2 / 2 / 3 slots (`VisualQuality.beam_cap`), one draw call: slot one follows
## the torch or the charge, the others are the flash of a shot. A friendly beam is drawn THIN (at most 0.36 m) so a danger decal, which is
## wider, is never hidden by it (SPEC 12.3 b). Reduced Flash dims the ribbon. The Lance Platform's own beam is `FxBoss`.

const BEAM_Y: float = 0.9
const TORCH_WIDTH_M: float = 0.12
const TORCH_WIDTH_PER_HIT_M: float = 0.012
const TORCH_WIDTH_MAX_M: float = 0.36
const CHARGE_WIDTH_M: float = 0.05
const SHOT_WIDTH_M: float = 0.45
const SHOT_LIFE_S: float = 0.12
const HOLD_LIFE_S: float = 0.2  ## a followed beam outlives one frame, so a slow frame never flickers it
const DIM_SCALE: float = 0.5
const MAX_PIERCE_SPARKS: int = 8
const SPARK_LIFE_S: float = 0.24

var beams: VfxPool

var _ctx: FxContext
var _sparks: VfxPool
var _lit: ArrayMesh
var _dim: ArrayMesh
var _follow: int = -1  ## the pool slot that follows the torch or the charge line
var shots: int = 0  ## lance shots drawn (tests, reports)


func setup(parent: Node3D, bounds: AABB, sparks: VfxPool, ctx: FxContext) -> void:
	_ctx = ctx
	_sparks = sparks
	_lit = VfxMeshes.bolt(&"add_cyan", &"add_white")
	_dim = VfxMeshes.bolt(&"add_cyan", &"add_white", DIM_SCALE)
	beams = VfxPool.new()
	beams.setup(parent, "Beams", _lit, VisualQuality.BEAM_CAP[VisualQuality.Tier.HIGH], VfxPool.Mode.BEAM, bounds)
	set_quality(ctx.tier)


func pools() -> Array[VfxPool]:
	return [beams]


func set_quality(tier: int) -> void:
	beams.set_limit(VisualQuality.beam_cap(tier))


func set_reduced(on: bool) -> void:
	beams.set_mesh(_dim if on else _lit)


func unbind() -> void:
	_follow = -1


## Once per rendered frame: the torch ribbon and the charge line follow their shooter and target.
func step() -> void:
	var sim: SimWorld = _ctx.sim
	var from: Vector3 = Vector3.INF
	var to: Vector3 = Vector3.INF
	var width: float = 0.0
	if sim != null and sim.content.is_variety():
		from = _ctx.actors.warden_muzzle_position()
		if sim.warden.weapon_index == Ids.WP_CUTTING_TORCH and sim.arsenal.beam_target > 0 and sim.arsenal.swap_left == 0:
			to = _ctx.actors.enemy_hit_position(sim.arsenal.beam_target)
			width = minf(TORCH_WIDTH_M + TORCH_WIDTH_PER_HIT_M * float(sim.arsenal.beam_hits), TORCH_WIDTH_MAX_M)
		elif sim.warden.weapon_index == Ids.WP_RAIL_LANCE and sim.arsenal.charge_left > 0:
			to = Vector3(sim.arsenal.charge_x, BEAM_Y, sim.arsenal.charge_z)
			width = CHARGE_WIDTH_M
	if from.is_finite() and to.is_finite() and beams.limit > 0:
		if beams.is_live(_follow):
			beams.retarget(_follow, from, to, HOLD_LIFE_S, width)
		else:
			_follow = beams.spawn(from, to, width, width, HOLD_LIFE_S)
	elif _follow >= 0:
		beams.release(_follow)
		_follow = -1


## Whether `source`'s shots are drawn by a beam instead of a tracer (the torch and the lance of the Warden).
func owns_shot(source: int) -> bool:
	if source != DamageSource.Id.WARDEN or _ctx.sim == null:
		return false
	var weapon: int = _ctx.sim.warden.weapon_index
	return weapon == Ids.WP_CUTTING_TORCH or weapon == Ids.WP_RAIL_LANCE


## `shot_fired` of a beam weapon: the torch needs nothing here (its ribbon follows), the lance fires its white line.
func shot(source: int, from: Vector3, hit: Vector3) -> void:
	var sim: SimWorld = _ctx.sim
	if sim == null or source != DamageSource.Id.WARDEN or sim.warden.weapon_index != Ids.WP_RAIL_LANCE:
		return
	if not from.is_finite() or not hit.is_finite() or beams.limit < 2:
		return
	var range_m: float = _ctx.content.weapons[Ids.WP_RAIL_LANCE].range_m
	var dir: Vector3 = Vector3(hit.x - from.x, 0.0, hit.z - from.z)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var end: Vector3 = Vector3(from.x + dir.x * range_m, BEAM_Y, from.z + dir.z * range_m)
	var _slot: int = beams.spawn(from, end, SHOT_WIDTH_M, SHOT_WIDTH_M * 0.5, SHOT_LIFE_S)
	shots += 1
	_pierce_sparks(sim, from, end)


## Sparks at every enemy that stands on the line (what the lance goes through), at most a handful.
func _pierce_sparks(sim: SimWorld, a: Vector3, b: Vector3) -> void:
	var st: EnemyStore = sim.enemies
	var made: int = 0
	for i: int in st.high_water:
		if made >= MAX_PIERCE_SPARKS:
			return
		if st.alive[i] == 0:
			continue
		var on: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(st.x[i], st.z[i]), Vector2(a.x, a.z), Vector2(b.x, b.z))
		if on.distance_to(Vector2(st.x[i], st.z[i])) > _ctx.content.enemies[st.type[i]].radius + 0.3:
			continue
		var at: Vector3 = _ctx.actors.enemy_hit_position(st.id[i])
		if not at.is_finite():
			continue
		made += 1
		for _k: int in 2:
			var vel: Vector3 = Vector3(_ctx.rng.randf_range(-3.0, 3.0), _ctx.rng.randf_range(2.0, 4.0), _ctx.rng.randf_range(-3.0, 3.0))
			var _spark: int = _sparks.spawn(at, vel, 0.5, 0.06, SPARK_LIFE_S)
