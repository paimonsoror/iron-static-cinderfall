class_name FxBlasts
extends RefCounted
## Blast effects (VARIETY_SPEC 10.4, 12.3 `fx_blast`): a ground ring on every `area_blast`, plus on MID a flash and on HIGH four
## debris streaks (the existing spark pool). Amber for CHORUS blasts, shells, missiles and drums; cyan for what is ours (the Deadfall
## Strike, the Core Vent): the ring AND the flash take the colour. Four pooled MultiMeshes (a pool that draws nothing costs no draw
## call), allocated once at the HIGH size and limited by tier (`VisualQuality.blast_rings` and `blast_flashes`). Pool exhaustion drops the OLDEST visual and never touches the sim.
## Rule of the frame (a test): a blast never draws on a slot that was already recycled in the same frame, so when more blasts arrive
## between two draws than a pool has slots, the surplus is dropped instead of overwriting a blast that has not been seen yet.
## Reduced Flash removes the flash billboards and dims the rings (nothing that covers more than 5 percent of the screen is bright for
## longer than 0.25 s: the flash lives 0.2 s). The same cyan ring pool draws the arc hit rings and the crate pulses.
## V4-X (readability, found on the slice captures: the 1.2 m blast of a volatile skitter at the far edge was a speck): every blast is drawn
## at least MIN_RING_M wide whatever its radius (the zone that hurts is told by the telegraph, a blast is an event), a thick band, and the
## flash is a soft glow under the spikes; both are multiplied by `scale` (FxScale) so an effect keeps its size on the screen at the far edge.

const RING_Y: float = 0.07
const FLASH_Y: float = 0.8
const RING_LIFE_S: float = 0.45
const RING_LIFE_BIG_S: float = 0.6
const FLASH_LIFE_S: float = 0.2
const BIG_RADIUS_M: float = 3.0
const RING_DIM: float = 0.5
const MIN_RING_M: float = 1.6  ## the smallest a blast ring is drawn, in meters (a volatile skitter's 1.2 m blast is drawn 1.6 m)
const RING_BAND: float = 0.6  ## inner radius of the ring band (the inside of a blast stays clear)
const FLASH_MIN_M: float = 1.2
const FLASH_MAX_M: float = 2.6  ## the biggest flash star, in meters of radius (the same as before: its area stays under 5 percent of the yard)

var rings_amber: VfxPool
var rings_cyan: VfxPool
var flashes: VfxPool
var flashes_cyan: VfxPool

var scale: FxScale = FxScale.new()  ## set by FxChaos; without a camera it is 1.0 everywhere

var _sparks: VfxPool
var _rng: RandomNumberGenerator
var _tier: int = VisualQuality.Tier.HIGH
var _reduced: bool = false
var _lit: Dictionary[StringName, ArrayMesh] = {}
var _dim: Dictionary[StringName, ArrayMesh] = {}
var _frame_amber: int = 0
var _frame_cyan: int = 0
var _frame_flash: int = 0
var _frame_flash_cyan: int = 0
var dropped: int = 0  ## blasts not drawn because the pool had no slot that was safe to take (tests, reports)


func setup(parent: Node3D, bounds: AABB, sparks: VfxPool, rng: RandomNumberGenerator) -> void:
	_sparks = sparks
	_rng = rng
	_lit[&"amber"] = VfxMeshes.ring(RING_BAND, 40, &"add_amber", &"add_white")
	_dim[&"amber"] = VfxMeshes.ring(RING_BAND, 40, &"add_amber", &"add_white", RING_DIM)
	_lit[&"cyan"] = VfxMeshes.ring(RING_BAND, 40, &"add_cyan", &"add_white")
	_dim[&"cyan"] = VfxMeshes.ring(RING_BAND, 40, &"add_cyan", &"add_white", RING_DIM)
	rings_amber = _pool(parent, "BlastRings", _lit[&"amber"], VisualQuality.BLAST_RING_CAP[VisualQuality.Tier.HIGH], VfxPool.Mode.FLAT, bounds)
	rings_cyan = _pool(parent, "CyanRings", _lit[&"cyan"], VisualQuality.BLAST_RING_CAP[VisualQuality.Tier.HIGH], VfxPool.Mode.FLAT, bounds)
	var flash_cap: int = VisualQuality.BLAST_FLASH_CAP[VisualQuality.Tier.HIGH]
	flashes = _pool(parent, "BlastFlashes", VfxMeshes.blast_flash(&"add_amber", &"add_white"), flash_cap, VfxPool.Mode.BILLBOARD, bounds)
	flashes_cyan = _pool(parent, "CyanFlashes", VfxMeshes.blast_flash(&"add_cyan", &"add_white"), flash_cap, VfxPool.Mode.BILLBOARD, bounds)
	set_quality(_tier)


func pools() -> Array[VfxPool]:
	return [rings_amber, rings_cyan, flashes, flashes_cyan]


func set_quality(tier: int) -> void:
	_tier = VisualQuality.from_setting(tier)
	rings_amber.set_limit(VisualQuality.blast_rings(_tier))
	rings_cyan.set_limit(VisualQuality.blast_rings(_tier))
	flashes.set_limit(VisualQuality.blast_flashes(_tier))
	flashes_cyan.set_limit(VisualQuality.blast_flashes(_tier))


## Reduced Flash: no flash billboards, dimmer rings.
func set_reduced(on: bool) -> void:
	_reduced = on
	rings_amber.set_mesh((_dim if on else _lit)[&"amber"])
	rings_cyan.set_mesh((_dim if on else _lit)[&"cyan"])


## Call once per rendered frame after the pools stepped: the next blasts belong to the next frame.
func frame_done() -> void:
	_frame_amber = 0
	_frame_cyan = 0
	_frame_flash = 0
	_frame_flash_cyan = 0


## `area_blast(kind, x, z, radius)`: the ring, the flash (MID, HIGH, not under Reduced Flash) and the streaks (HIGH).
func blast(kind: int, x: float, z: float, radius: float) -> void:
	var r: float = clampf(radius, 0.4, 12.0)
	if r < BIG_RADIUS_M:  # a big blast is a real zone (the strike, a vent) and is drawn at its true radius; a small one is boosted to stay readable
		r = minf(maxf(r, MIN_RING_M) * maxf(1.0, scale.at(Vector3(x, 0.0, z))), BIG_RADIUS_M)  # never drawn smaller than MIN_RING_M
	var ours: bool = kind == HazardState.K_STRIKE or kind == HazardState.K_VENT
	var life: float = RING_LIFE_BIG_S if r >= BIG_RADIUS_M else RING_LIFE_S
	var slot: int = ring(ours, Vector3(x, RING_Y, z), r * 0.2, r, life)
	if slot < 0:
		return  # no slot was safe to take: the whole blast is dropped, flash and streaks too
	var at: Vector3 = Vector3(x, FLASH_Y, z)
	var flash_pool: VfxPool = flashes_cyan if ours else flashes
	var used: int = _frame_flash_cyan if ours else _frame_flash
	if not _reduced and flash_pool.limit > 0 and used < flash_pool.limit:
		if ours:
			_frame_flash_cyan += 1
		else:
			_frame_flash += 1
		var size: float = clampf(r * 0.8 + 0.3, FLASH_MIN_M, FLASH_MAX_M)
		var _flash: int = flash_pool.spawn(at, Vector3.ZERO, size, size * 0.3, FLASH_LIFE_S, _rng.randf_range(0.0, TAU))
	for _k: int in VisualQuality.blast_streaks(_tier):
		var ang: float = _rng.randf_range(0.0, TAU)
		var vel: Vector3 = Vector3(cos(ang) * _rng.randf_range(4.0, 7.0), _rng.randf_range(2.0, 4.5), sin(ang) * _rng.randf_range(4.0, 7.0))
		var _streak: int = _sparks.spawn(at, vel, 0.6, 0.06, _rng.randf_range(0.2, 0.34))


## One ring on the ground (cyan or amber), `r0` to `r1` over `life` seconds. Returns the slot, or -1 when the pool is limited to
## nothing or every slot was already used in this frame (the surplus is dropped, see the class comment).
func ring(cyan: bool, at: Vector3, r0: float, r1: float, life: float) -> int:
	var pool: VfxPool = rings_cyan if cyan else rings_amber
	var used: int = _frame_cyan if cyan else _frame_amber
	if pool.limit <= 0 or used >= pool.limit:
		dropped += 1
		return -1
	if cyan:
		_frame_cyan += 1
	else:
		_frame_amber += 1
	return pool.spawn(at, Vector3.ZERO, r0, r1, life, _rng.randf_range(0.0, TAU))


## The crate landing, being secured or lost: a cyan ring (red-amber when lost) at the crate.
func crate_pulse(at: Vector3, secured: bool) -> void:
	var _slot: int = ring(secured, Vector3(at.x, RING_Y, at.z), 0.6, 2.4 if secured else 1.4, 0.5)


func live_rings() -> int:
	return rings_amber.live_count() + rings_cyan.live_count()


func _pool(parent: Node3D, node_name: String, mesh_res: Mesh, cap: int, pool_mode: int, bounds: AABB) -> VfxPool:
	var pool: VfxPool = VfxPool.new()
	pool.setup(parent, node_name, mesh_res, cap, pool_mode, bounds)
	return pool
