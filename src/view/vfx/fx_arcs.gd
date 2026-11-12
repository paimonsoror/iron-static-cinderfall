class_name FxArcs
extends RefCounted
## Chain lightning (VARIETY_SPEC 3.5 arc projector, 12.3 `fx_arc`): on every `chain_arc(from_id, to_id)` a jagged cyan-white bolt of
## three jittered segments runs from the Warden's muzzle (from_id 0) or the last enemy to the next one, and a small blue-white ring
## flares on the ground under the enemy it reaches (the cyan ring pool of FxBlasts, like the EMP rings of the concept image). One
## pooled SEGMENT MultiMesh allocated at the HIGH size (45) and limited by tier (18 / 30 / 45 = 6 / 10 / 15 jumps), one draw call.
## Friendly arcs are drawn thin (0.1 m at the muzzle end, 0.03 at the far end) so a danger decal is always wider than the bolt over
## it. The jitter comes from a view-only RNG; the sim is never asked anything. Reduced Flash dims the bolt (the core stays).
## An enemy killed by the jump before the next jump is drawn is still found: the position of the last jump's target is remembered.
## Same frame rule as the blasts: no segment is overwritten by another segment of the same frame.

const SEGMENTS_PER_JUMP: int = 3
const LIFE_S: float = 0.18
const WIDTH_START: float = 0.1
const WIDTH_END: float = 0.03
const JITTER_FRACTION: float = 0.13
const JITTER_MAX_M: float = 0.4
const HIT_RING_R0: float = 0.15
const HIT_RING_R1: float = 0.85
const HIT_RING_LIFE_S: float = 0.3
const RING_Y: float = 0.07
const DIM_SCALE: float = 0.5

var segments: VfxPool

var _actors: ActorLayer
var _blasts: FxBlasts
var _rng: RandomNumberGenerator
var _lit: ArrayMesh
var _dim: ArrayMesh
var _frame: int = 0
var _last_to: int = -1
var _last_at: Vector3 = Vector3.INF
var jumps: int = 0  ## jumps drawn so far (tests, reports)
var dropped: int = 0  ## jumps not drawn because no segment was safe to take


func setup(parent: Node3D, bounds: AABB, actors: ActorLayer, blasts: FxBlasts, rng: RandomNumberGenerator) -> void:
	_actors = actors
	_blasts = blasts
	_rng = rng
	_lit = VfxMeshes.bolt(&"add_cyan", &"add_white")
	_dim = VfxMeshes.bolt(&"add_cyan", &"add_white", DIM_SCALE)
	segments = VfxPool.new()
	segments.setup(parent, "ArcSegments", _lit, VisualQuality.ARC_SEGMENT_CAP[VisualQuality.Tier.HIGH], VfxPool.Mode.SEGMENT, bounds)


func pools() -> Array[VfxPool]:
	return [segments]


func set_quality(tier: int) -> void:
	segments.set_limit(VisualQuality.arc_segments(tier))


func set_reduced(on: bool) -> void:
	segments.set_mesh(_dim if on else _lit)


func frame_done() -> void:
	_frame = 0


func forget() -> void:
	_last_to = -1
	_last_at = Vector3.INF
	_frame = 0


## One jump of a chain. False when an end of it is not in the view (nothing is drawn) or no segment was safe to take.
func arc(from_id: int, to_id: int) -> bool:
	var a: Vector3 = _actors.warden_muzzle_position() if from_id == 0 else _actors.enemy_hit_position(from_id)
	if from_id != 0 and not a.is_finite() and from_id == _last_to:
		a = _last_at
	var b: Vector3 = _actors.enemy_hit_position(to_id)
	if not a.is_finite() or not b.is_finite():
		return false
	_last_to = to_id
	_last_at = b
	if segments.limit < SEGMENTS_PER_JUMP or _frame + SEGMENTS_PER_JUMP > segments.limit:
		dropped += 1
		return false
	_frame += SEGMENTS_PER_JUMP
	var span: Vector3 = b - a
	var length: float = span.length()
	var side: Vector3 = Vector3.UP.cross(span.normalized()) if length > 0.01 else Vector3.RIGHT
	var amp: float = minf(length * JITTER_FRACTION, JITTER_MAX_M)
	var prev: Vector3 = a
	for k: int in SEGMENTS_PER_JUMP:
		var next: Vector3 = b
		if k < SEGMENTS_PER_JUMP - 1:
			var t: float = float(k + 1) / float(SEGMENTS_PER_JUMP)
			next = a + span * t + side * (_rng.randf_range(-1.0, 1.0) * amp) + Vector3(0.0, _rng.randf_range(-0.5, 0.5) * amp, 0.0)
		var _slot: int = segments.spawn(prev, next, WIDTH_START, WIDTH_END, LIFE_S)
		prev = next
	var _ring: int = _blasts.ring(true, Vector3(b.x, RING_Y, b.z), HIT_RING_R0, HIT_RING_R1, HIT_RING_LIFE_S)
	jumps += 1
	return true
