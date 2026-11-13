class_name FxStrike
extends RefCounted
## The Deadfall Strike from call to aftermath (VARIETY_SPEC 7.2, 12.3 `fx_strike_column`; V4-X). Warning: a beacon (a small cyan-lit tripod, one
## node of about 100 triangles) stands on the target from the moment the round is in the air until it lands, under the falling column of
## light and the closing ring that `FxTelegraph` draws. Effect: on the blast (`area_blast` of kind STRIKE) a tall column of cyan-white light
## flashes where it hit (MID and HIGH, never under Reduced Flash: it is a flash). Aftermath: wreck sparks drizzle from the crater for 1.4 s
## (a steady trickle on HIGH, a thin one on MID, none on LOW) over the big scorch mark that `FxCosmetic` leaves. Everything here is ours, so it
## is cyan; the ring of the blast itself is `FxBlasts`. The beacon and the column never hide a danger decal (the column is thin and tall,
## the beacon is 0.3 m wide).

const COLUMN_HEIGHT_M: float = 14.0
const COLUMN_WIDTH_M: float = 1.2
const COLUMN_LIFE_S: float = 0.22
const AFTERMATH_S: float = 1.4
const SPARK_EVERY_S: Array[float] = [0.0, 0.18, 0.07]  ## per tier: none, thin, steady
const BEACON_Y: float = 0.0

var column: VfxPool
var beacon: MeshInstance3D

var impacts: int = 0  ## strikes that landed (tests, reports)

var _ctx: FxContext
var _sparks: VfxPool
var _lit: ArrayMesh
var _dim: ArrayMesh
var _beacon_left: float = 0.0
var _site: Vector3 = Vector3.INF
var _aftermath_left: float = 0.0
var _spark_cd: float = 0.0


func setup(parent: Node3D, bounds: AABB, sparks: VfxPool, ctx: FxContext) -> void:
	_ctx = ctx
	_sparks = sparks
	_lit = VfxMeshes.bolt(&"add_cyan", &"add_white")
	_dim = VfxMeshes.bolt(&"add_cyan", &"add_white", 0.5)
	column = VfxPool.new()
	column.setup(parent, "StrikeColumn", _lit, 2, VfxPool.Mode.BEAM, bounds)
	beacon = MeshInstance3D.new()
	beacon.name = "StrikeBeacon"
	beacon.mesh = _beacon_mesh()
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.visible = false
	parent.add_child(beacon)


func pools() -> Array[VfxPool]:
	return [column]


func set_reduced(on: bool) -> void:
	column.set_mesh(_dim if on else _lit)


func unbind() -> void:
	beacon.visible = false
	_beacon_left = 0.0
	_aftermath_left = 0.0
	_site = Vector3.INF


## `delayed_hit(kind, x, z, ticks)`: a strike round in the air puts the beacon on its target until it lands.
func delayed(kind: int, x: float, z: float, ticks: int) -> void:
	if kind != HazardState.K_STRIKE:
		return
	beacon.position = Vector3(x, BEACON_Y, z)
	beacon.visible = true
	_beacon_left = maxf(float(ticks) * SimWorld.DT, 0.05)


## `area_blast(kind, x, z, radius)`: the strike lands.
func blast(kind: int, x: float, z: float, _radius: float) -> void:
	if kind != HazardState.K_STRIKE:
		return
	impacts += 1
	beacon.visible = false
	_beacon_left = 0.0
	_site = Vector3(x, 0.3, z)
	_aftermath_left = AFTERMATH_S
	if _ctx.tier != VisualQuality.Tier.LOW and not _ctx.reduced:
		var _slot: int = column.spawn(Vector3(x, 0.1, z), Vector3(x, COLUMN_HEIGHT_M, z), COLUMN_WIDTH_M, COLUMN_WIDTH_M * 0.25, COLUMN_LIFE_S)


## Once per rendered frame: the beacon leaves with its round, the crater throws sparks.
func step(delta: float) -> void:
	if _beacon_left > 0.0:
		_beacon_left -= delta
		if _beacon_left <= 0.0:
			beacon.visible = false
	if _aftermath_left <= 0.0:
		return
	_aftermath_left -= delta
	var every: float = SPARK_EVERY_S[clampi(_ctx.tier, 0, 2)]
	if every <= 0.0:
		return
	_spark_cd -= delta
	if _spark_cd > 0.0:
		return
	_spark_cd = every
	var ang: float = _ctx.rng.randf_range(0.0, TAU)
	var out: float = _ctx.rng.randf_range(0.5, 2.0)
	var vel: Vector3 = Vector3(cos(ang) * out, _ctx.rng.randf_range(2.0, 4.0), sin(ang) * out)
	var off: Vector3 = Vector3(_ctx.rng.randf_range(-1.2, 1.2), 0.0, _ctx.rng.randf_range(-1.2, 1.2))
	var _spark: int = _sparks.spawn(_site + off, vel, 0.45, 0.05, _ctx.rng.randf_range(0.2, 0.34))


func aftermath_active() -> bool:
	return _aftermath_left > 0.0


## A tripod with a cyan light on top: 100 triangles at most (SPEC 12.2).
func _beacon_mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.prism(Vector3(0.7, 0.1, 0.7), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0)), &"dark_frame")
	mb.cylinder(0.04, 0.09, 1.2, 6, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.7, 0.0)), &"gunmetal")
	mb.sphere(0.14, 6, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.38, 0.0)), &"emit_cyan")
	return mb.build()
