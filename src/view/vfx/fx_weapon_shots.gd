class_name FxWeaponShots
extends RefCounted
## What each gun's shot looks like on top of the tracer and the muzzle star every shot gets (VARIETY_SPEC 8.2 "shot look", 10.4; V5-B):
##   scattergun     eight thin streaks fanned out of the muzzle, 9 m long, and a dust kick at the muzzle
##   assault_rifle  the tracer goes on through the first target as a thinner line
##   lmg            two more sparks per hit and a brass case flung out of the gun (MID and HIGH; none on LOW)
## The Warden's weapon is read from the sim (the shot event carries none); a turret's shot and the other guns get nothing extra. It draws
## into the layer's own tracer, spark and dust pools and owns one pool of its own, the brass (one draw call, nothing on LOW).

const FAN_STREAKS: int = 8
const FAN_HALF_ANGLE: float = 0.38  ## radians either side of the aim (about 22 degrees wide in all)
const FAN_LENGTH_M: float = 9.0
const FAN_LIFE_S: float = 0.14
const THROUGH_M: float = 6.0
const THROUGH_LIFE_S: float = 0.14
const BRASS_CAP: int = 16
const BRASS_BY_TIER: Array[int] = [0, 8, 16]  ## brass cases alive at once per tier (SPEC 10.4)
const EXTRA_SPARKS: int = 2

var brass: VfxPool
var sim: SimWorld  ## set by VfxLayer.bind: the Warden's weapon is read from it

var _tracers: VfxPool
var _sparks: VfxPool
var _dust: VfxPool
var _rng: RandomNumberGenerator
var _tier: int = VisualQuality.Tier.HIGH


func setup(parent: Node3D, bounds: AABB, tracers: VfxPool, sparks: VfxPool, dust: VfxPool, rng: RandomNumberGenerator) -> void:
	_tracers = tracers
	_sparks = sparks
	_dust = dust
	_rng = rng
	brass = VfxPool.new()
	brass.setup(parent, "Brass", VfxMeshes.cube(&"emit_amber"), BRASS_CAP, VfxPool.Mode.DEBRIS, bounds)
	set_quality(_tier)


func pools() -> Array[VfxPool]:
	return [brass]


func set_quality(tier: int) -> void:
	_tier = clampi(tier, 0, BRASS_BY_TIER.size() - 1)
	brass.set_limit(BRASS_BY_TIER[_tier])


## The extras of one shot of `source` from `from` at `hit` (`has_target`: `hit` is an enemy, not just the aim point).
func shot(source: int, from: Vector3, hit: Vector3, has_target: bool) -> void:
	if sim == null or source != DamageSource.Id.WARDEN:
		return
	var along: Vector3 = Vector3(hit.x - from.x, 0.0, hit.z - from.z)
	if along.length() < 0.05:
		return
	along = along.normalized()
	match Ids.WEAPONS[clampi(sim.warden.weapon_index, 0, Ids.WEAPONS.size() - 1)]:
		&"scattergun":
			_fan(from, along, hit.y)
		&"assault_rifle":
			if has_target:
				var _line: int = _tracers.spawn(hit, hit + along * THROUGH_M, 0.09, 0.03, THROUGH_LIFE_S)
		&"lmg":
			_brass(from, along)
			if has_target:
				_sparks_at(hit, along)


## Eight thin streaks across the aim, and a puff of dust where the shells left.
func _fan(from: Vector3, along: Vector3, height: float) -> void:
	for k: int in FAN_STREAKS:
		var angle: float = lerpf(-FAN_HALF_ANGLE, FAN_HALF_ANGLE, float(k) / float(FAN_STREAKS - 1)) + _rng.randf_range(-0.03, 0.03)
		var dir: Vector3 = along.rotated(Vector3.UP, angle)
		var end: Vector3 = Vector3(from.x + dir.x * FAN_LENGTH_M, height, from.z + dir.z * FAN_LENGTH_M)
		var _streak: int = _tracers.spawn(from, end, 0.06, 0.025, FAN_LIFE_S)
	var _puff: int = _dust.spawn(from + along * 0.5 + Vector3(0.0, -0.4, 0.0), Vector3.ZERO, 0.35, 1.1, 0.35)


## A brass case flung out to the side of the gun, up and back, tumbling, resting on the ground.
func _brass(from: Vector3, along: Vector3) -> void:
	var side: Vector3 = along.cross(Vector3.UP)
	var vel: Vector3 = side * _rng.randf_range(1.6, 2.8) - along * _rng.randf_range(0.2, 0.8) + Vector3(0.0, _rng.randf_range(1.8, 3.0), 0.0)
	var size: float = _rng.randf_range(0.07, 0.1)
	var _case: int = brass.spawn(from, vel, size, size, _rng.randf_range(0.7, 1.1), _rng.randf_range(-12.0, 12.0))


func _sparks_at(hit: Vector3, along: Vector3) -> void:
	for _i: int in EXTRA_SPARKS:
		var jitter: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * 0.8
		var dir: Vector3 = (-along * _rng.randf_range(0.3, 1.0) + jitter).normalized()
		var vel: Vector3 = dir * _rng.randf_range(3.5, 7.0) + Vector3(0.0, _rng.randf_range(1.5, 3.5), 0.0)
		var _spark: int = _sparks.spawn(hit, vel, 0.5, 0.06, _rng.randf_range(0.18, 0.3))


## The sparks of a hit at `at`, thrown back toward `away` (from the target to the shooter), `n` of them at `power`.
func impact_sparks(at: Vector3, away: Vector3, n: int, power: float) -> void:
	var flat: Vector3 = Vector3(away.x, 0.0, away.z)
	var base: Vector3 = Vector3.LEFT
	if flat.length() > 0.01:
		base = flat.normalized()
	for _i: int in n:
		var jitter: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * 0.8
		var dir: Vector3 = (base * _rng.randf_range(0.3, 1.0) + jitter).normalized()
		var vel: Vector3 = dir * _rng.randf_range(3.5, 7.0) * power + Vector3(0.0, _rng.randf_range(1.5, 3.5), 0.0)
		var _spark: int = _sparks.spawn(at, vel, 0.5 * power, 0.06, _rng.randf_range(0.18, 0.3))
