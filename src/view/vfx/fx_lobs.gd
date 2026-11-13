class_name FxLobs
extends RefCounted
## Things in the air (VARIETY_SPEC 10.3 `fx_lob`; V4-X): the mortar's slag shell (an amber-white ball on a high arc), the hornets of the rack
## (small balls on low arcs that fan out of the muzzle) and the spitter's bolt (a RED ball on its way to the core). Each is a BILLBOARD that
## flies from its origin to the point the sim says it lands (`delayed_hit(kind, x, z, ticks)`) in exactly the ticks the sim gives, so the
## ball arrives on the tick the blast starts; the ground ring under it is the telegraph (`FxTelegraph.delayed`), this is the thing itself.
## One colour per pool (SPEC 5.6 rule 3): shells are amber-white, hornets cyan-white and the enemy's bolt is red. Pools (allocated once at the HIGH size): shells 4 slots and hornets 20, together limited to the
## tier's 12 / 18 / 24 (`VisualQuality.lob_cap`, shells first); the spitter's bolts 12 slots on EVERY tier, because an enemy projectile
## is never tier-gated. The origin of a shell or a hornet is the Warden's muzzle; the origin of a bolt is the spitter that fired it (the one
## whose timer was just reset, else the nearest to the core), else the standoff ring. Pool exhaustion drops the oldest.

const SHELL_SLOTS: int = 4
const SHELL_SIZE_M: float = 0.5
const HORNET_SIZE_M: float = 0.22
const BOLT_SIZE_M: float = 0.36
const BOLT_HEIGHT_M: float = 1.0  ## the bolt lands this high on the core cage
const END_Y: float = 0.3
const START_Y: float = 1.1
const SHELL_ARC_PER_M: float = 0.28
const SHELL_ARC_MIN_M: float = 1.6
const SHELL_ARC_MAX_M: float = 6.0
const STANDOFF_FALLBACK_M: float = 10.5  ## where a bolt of an unknown spitter starts, east of its target

var shells: VfxPool
var hornets: VfxPool
var bolts: VfxPool

var launched: int = 0  ## lobs started (tests, reports)

var _ctx: FxContext


func setup(parent: Node3D, bounds: AABB, ctx: FxContext) -> void:
	_ctx = ctx
	var friendly: int = VisualQuality.LOB_CAP[VisualQuality.Tier.HIGH]
	shells = _make(parent, "LobShells", VfxMeshes.orb(&"add_amber", &"add_white"), SHELL_SLOTS, bounds)
	hornets = _make(parent, "LobHornets", VfxMeshes.orb(&"add_cyan", &"add_white"), friendly - SHELL_SLOTS, bounds)
	bolts = _make(parent, "LobBolts", VfxMeshes.orb(&"add_red", &"add_red"), VisualQuality.BOLT_CAP[VisualQuality.Tier.HIGH], bounds)
	set_quality(ctx.tier)


func pools() -> Array[VfxPool]:
	return [shells, hornets, bolts]


func set_quality(tier: int) -> void:
	var friendly: int = VisualQuality.lob_cap(tier)
	shells.set_limit(mini(SHELL_SLOTS, friendly))
	hornets.set_limit(friendly - shells.limit)
	bolts.set_limit(VisualQuality.bolt_cap(tier))


## Facing of the billboards; set once per rendered frame.
func face(facing: Basis) -> void:
	shells.facing = facing
	hornets.facing = facing
	bolts.facing = facing


## `delayed_hit(kind, x, z, ticks)`: the flying thing of a shell, a missile or a spitter's bolt.
func launched_hit(kind: int, x: float, z: float, ticks: int) -> void:
	var life: float = maxf(float(ticks) * SimWorld.DT, 0.05)
	var end: Vector3 = Vector3(x, END_Y, z)
	match kind:
		HazardState.K_SHELL:
			var from: Vector3 = _muzzle()
			if from.is_finite():
				var height: float = clampf(from.distance_to(end) * SHELL_ARC_PER_M, SHELL_ARC_MIN_M, SHELL_ARC_MAX_M)
				_fly(shells, from, end, SHELL_SIZE_M, height, life)
		HazardState.K_MISSILE:
			var from: Vector3 = _muzzle()
			if from.is_finite():
				var side: Vector3 = Vector3(_ctx.rng.randf_range(-0.5, 0.5), _ctx.rng.randf_range(0.0, 0.3), _ctx.rng.randf_range(-0.5, 0.5))
				_fly(hornets, from + side, end, HORNET_SIZE_M, _ctx.rng.randf_range(1.0, 2.6), life)
		HazardState.K_BOLT:
			var from: Vector3 = _spitter_for(x, z)
			_fly(bolts, from, Vector3(x, BOLT_HEIGHT_M, z), BOLT_SIZE_M, 1.2, life)


func live_count() -> int:
	return shells.live_count() + hornets.live_count() + bolts.live_count()


func _fly(pool: VfxPool, from: Vector3, to: Vector3, size: float, height: float, life: float) -> void:
	var slot: int = pool.spawn(from, to, size, size, life, height)
	if slot >= 0:
		launched += 1


func _muzzle() -> Vector3:
	var at: Vector3 = _ctx.actors.warden_muzzle_position()
	return at if at.is_finite() else Vector3(_ctx.content.arena.warden_x, START_Y, _ctx.content.arena.warden_z)


## Where a bolt aimed at the core starts: the spitter that just fired, else the nearest one, else the standoff ring east of the core.
func _spitter_for(x: float, z: float) -> Vector3:
	var sim: SimWorld = _ctx.sim
	var best: int = -1
	if sim != null and sim.content.is_variety():
		var st: EnemyStore = sim.enemies
		var best_cd: int = -1
		var best_d: float = INF
		for i: int in st.high_water:
			if st.alive[i] == 0 or st.type[i] != Ids.EN_SPITTER:
				continue
			var d: float = Vector2(st.x[i] - x, st.z[i] - z).length()
			if sim.ext.aux_cd[i] > best_cd or (sim.ext.aux_cd[i] == best_cd and d < best_d):
				best = i
				best_cd = sim.ext.aux_cd[i]
				best_d = d
		if best >= 0:
			var at: Vector3 = _ctx.enemy_at(st.id[best])
			if at.is_finite():
				return Vector3(at.x, START_Y + 0.5, at.z)
	return Vector3(x + STANDOFF_FALLBACK_M, START_Y, z)


func _make(parent: Node3D, node_name: String, mesh_res: Mesh, cap: int, bounds: AABB) -> VfxPool:
	var pool: VfxPool = VfxPool.new()
	pool.setup(parent, node_name, mesh_res, cap, VfxPool.Mode.LOB, bounds)
	return pool
