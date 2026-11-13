class_name FxCosmetic
extends RefCounted
## Cosmetic chaos that is not information (VARIETY_SPEC 10.2, 10.4, 12.3 `fx_scorch`; V4-X): scorch marks left by blasts, embers drifting up
## after them, a short downpour when a world event starts, and the camera shaking under big blasts. All of it is scaled by the quality tier
## (`VisualQuality`: none on LOW, light on MID, full on HIGH) and none of it is ever the only carrier of a fact: the ring, the telegraph
## and the pool say what happened. Reduced Flash switches the shake off at every tier (GDD 10.3). The ghost swarm massing outside the gates
## is `FxGhosts`. Everything is allocated once at the HIGH size; a tier only limits how much of a pool is used. View-only RNG, never the sim.
##
## Scorch marks are a persistent ring buffer: they stay until the next mark takes the slot (45 s at most), are dark and calm (one black
## shadow material, a faint warm rim), and never stack more than two deep in a small area because a blast leaves one mark.

const SCORCH_Y: float = 0.034
const SCORCH_LIFE_S: float = 45.0
const SCORCH_MIN_M: float = 0.7
const SCORCH_MAX_M: float = 2.6
const EMBER_Y: float = 0.5
const RAIN_HEIGHT_M: float = 9.0
const SHAKE_MAX_M: float = 0.32  ## camera offset at full trauma and full tier gain, meters
const SHAKE_DECAY: float = 2.4  ## trauma per second
const SHAKE_HZ: float = 26.0
## Blast kinds that leave a mark, and how much trauma a blast of that kind shakes the camera with (per meter of radius).
const MARK_KINDS: Array[int] = [HazardState.K_BLAST, HazardState.K_SHELL, HazardState.K_MISSILE, HazardState.K_DRUM, HazardState.K_STRIKE]
const SHAKE_KINDS: Array[int] = [HazardState.K_BLAST, HazardState.K_SHELL, HazardState.K_DRUM, HazardState.K_STRIKE, HazardState.K_VENT]

var scorch: VfxPool
var embers: VfxPool
var rain: VfxPool
var ghosts: FxGhosts = FxGhosts.new()

var trauma: float = 0.0  ## 0..1, decays by itself
var marks: int = 0  ## scorch marks laid since the last unbind (tests, reports)

var _ctx: FxContext
var _t: float = 0.0
var _last_offset: Vector2 = Vector2.ZERO


func setup(parent: Node3D, bounds: AABB, ctx: FxContext) -> void:
	_ctx = ctx
	scorch = VfxPool.new()
	scorch.setup(parent, "ScorchMarks", VfxMeshes.scorch_mark(), VisualQuality.SCORCH_CAP[VisualQuality.Tier.HIGH], VfxPool.Mode.FLAT, bounds)
	embers = VfxPool.new()
	embers.setup(parent, "Embers", VfxMeshes.star(&"add_amber", &"add_white", 0.8), VisualQuality.EMBER_CAP[VisualQuality.Tier.HIGH], VfxPool.Mode.DRIFT, bounds)
	rain = VfxPool.new()
	rain.setup(parent, "RainBurst", VfxMeshes.streak(&"rain"), VisualQuality.RAIN_BURST_CAP[VisualQuality.Tier.HIGH], VfxPool.Mode.STREAK, bounds)
	rain.streak_width = 0.03
	ghosts.setup(parent, bounds, ctx)
	set_quality(ctx.tier)


func pools() -> Array[VfxPool]:
	return [scorch, embers, rain]


func set_quality(tier: int) -> void:
	scorch.set_limit(VisualQuality.scorch_marks(tier))
	embers.set_limit(VisualQuality.embers(tier))
	rain.set_limit(VisualQuality.rain_burst(tier))
	ghosts.set_quality(tier)
	if VisualQuality.shake_gain(tier) <= 0.0:
		trauma = 0.0


func set_reduced(on: bool) -> void:
	ghosts.set_reduced(on)
	if on:
		trauma = 0.0
		_apply_shake(0.0)


## Every blast: a scorch mark under it, embers over it and a shake of the camera when it is big. `radius` is the blast's own radius in meters.
func blast(kind: int, x: float, z: float, radius: float) -> void:
	if MARK_KINDS.has(kind) and scorch.limit > 0:
		var r: float = clampf(radius * 0.75, SCORCH_MIN_M, SCORCH_MAX_M)
		var _slot: int = scorch.spawn(Vector3(x, SCORCH_Y, z), Vector3.ZERO, r, r * 0.85, SCORCH_LIFE_S, _ctx.rng.randf_range(0.0, TAU))
		marks += 1
	for _k: int in VisualQuality.embers_per_blast(_ctx.tier):
		var drift: Vector3 = Vector3(_ctx.rng.randf_range(-0.6, 0.6), _ctx.rng.randf_range(1.0, 2.0), _ctx.rng.randf_range(-0.6, 0.6))
		var off: Vector3 = Vector3(_ctx.rng.randf_range(-0.6, 0.6), 0.0, _ctx.rng.randf_range(-0.6, 0.6)) * radius * 0.5
		var _ember: int = embers.spawn(Vector3(x, EMBER_Y, z) + off, drift, 0.2, 0.0, _ctx.rng.randf_range(0.7, 1.2))
	if SHAKE_KINDS.has(kind):
		shake(0.1 + radius * 0.07)


## Adds `amount` (0..1) of trauma; the camera shakes by trauma squared, by the tier's gain, and never under Reduced Flash.
func shake(amount: float) -> void:
	if _ctx.reduced or VisualQuality.shake_gain(_ctx.tier) <= 0.0:
		return
	trauma = minf(1.0, trauma + maxf(amount, 0.0))


## A world event starts: a short downpour over the yard (the pool is limited to none / light / full by the tier).
func event_started() -> void:
	for _n: int in rain.limit:
		var at: Vector3 = _ctx.random_in_yard(-2.0)
		var vel: Vector3 = Vector3(_ctx.rng.randf_range(0.5, 1.5), -_ctx.rng.randf_range(16.0, 22.0), 0.0)
		var _drop: int = rain.spawn(Vector3(at.x, RAIN_HEIGHT_M + _ctx.rng.randf_range(0.0, 3.0), at.z), vel, 1.4, 1.4, _ctx.rng.randf_range(0.3, 0.5))


## Once per rendered frame: the shake offset and the ghosts.
func step(delta: float, facing: Basis) -> void:
	_t += delta
	embers.facing = facing
	trauma = maxf(0.0, trauma - SHAKE_DECAY * delta)
	var strength: float = trauma * trauma * SHAKE_MAX_M * VisualQuality.shake_gain(_ctx.tier)
	if strength > 0.0:
		_apply_shake(strength)
	elif _last_offset != Vector2.ZERO:
		_apply_shake(0.0)
	ghosts.step(delta)


## The camera offset now in meters (tests read it; the camera itself is moved with `Camera3D.h_offset` and `v_offset`).
func shake_offset() -> Vector2:
	return _last_offset


func clear() -> void:
	trauma = 0.0
	marks = 0
	_apply_shake(0.0)
	ghosts.clear()


func _apply_shake(strength: float) -> void:
	var a: float = sin(_t * SHAKE_HZ * 1.7) + sin(_t * SHAKE_HZ * 0.6 + 1.3)
	var b: float = cos(_t * SHAKE_HZ * 1.3 + 0.4) + sin(_t * SHAKE_HZ * 0.9 + 2.1)
	_last_offset = Vector2(a, b) * 0.5 * strength
	if _ctx.rig != null and _ctx.rig.camera != null:
		_ctx.rig.camera.h_offset = _last_offset.x
		_ctx.rig.camera.v_offset = _last_offset.y
