class_name VfxLayer
extends Node3D
## All combat effects, pooled and capped (ARCH 13, GDD 12.3): tracers, muzzle flashes, impact sparks, death bursts,
## floating "+Scrap" texts, the EMP ring, the shield dome, the overdrive glow, core-hit sparks and boss footfall dust. V2-F added the
## chaos effects of the variety milestone through `FxChaos` (blasts, chain arcs, telegraphs, strike column, ground pools, crate pulses).
## Driven by `Events` (so it never touches sim state); it only reads the sim for the persistent shield and overdrive
## state. Pool exhaustion drops the oldest visual. Reduced Flash removes the full-screen flash and dims flashes.

const TRACER_CAP: int = 48
const SPARK_CAP: int = 64
const BURST_CAP: int = 24
const DEBRIS_PER_BURST: int = 4
const MUZZLE_CAP: int = 12
const RING_CAP: int = 2
const DUST_CAP: int = 12
const TRACER_LIFE_S: float = 0.16
const TRACER_LIFE_OVERDRIVE_S: float = 0.1
const EMP_RING_S: float = 0.75
const EMP_RING_RADIUS_M: float = 34.0
const CORE_FLASH_COOLDOWN_S: float = 1.2
## Alpha scale of the flash meshes under Reduced Flash.
const DIM: float = 0.45
## Per quality tier (LOW, MID, HIGH).
const SPARKS_PER_HIT: Array[int] = [2, 3, 4]
const DEBRIS_PER_DEATH: Array[int] = [2, 3, 4]
const TEXT_CAP_BY_TIER: Array[int] = [8, 12, 16]

var _rig: CameraRig
var _actors: ActorLayer
var _arena: ArenaDef
var _content: ContentSet
var _sim: SimWorld
var _pools: Array[VfxPool] = []
var _tracers: VfxPool
var _muzzles: VfxPool
var _sparks: VfxPool
var _debris: VfxPool
var _bursts: VfxPool
var _dust: VfxPool
var _rings: VfxPool
var _texts: FloatingTexts
var _auras: VfxAuras
var _flash: ScreenFlash
var _chaos: FxChaos
var _facing: Basis = Basis.IDENTITY  ## the camera-facing basis of the billboard pools, as of the last render
var _lit_meshes: Dictionary[StringName, ArrayMesh] = {}  ## full brightness, by pool name
var _dim_meshes: Dictionary[StringName, ArrayMesh] = {}  ## Reduced Flash copies
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _quality: int = VisualQuality.Tier.HIGH
var _reduced: bool = false
var _flash_cd: float = 0.0
var _text_color: Color = Color.WHITE


func setup(content: ContentSet, rig: CameraRig, actors: ActorLayer) -> void:
	_content = content
	_rig = rig
	_actors = actors
	_arena = content.arena
	_rng.seed = 20260511
	_text_color = content.tokens.color(&"core_amber")
	var bounds: AABB = AABB(
		Vector3(_arena.min_x - 40.0, -4.0, _arena.min_z - 40.0),
		Vector3(_arena.max_x - _arena.min_x + 80.0, 30.0, _arena.max_z - _arena.min_z + 80.0)
	)
	_tracers = _make_pool("Tracers", VfxMeshes.tracer(&"emit_amber"), TRACER_CAP, VfxPool.Mode.SEGMENT, bounds)
	_lit_meshes[&"muzzle"] = VfxMeshes.star(&"add_amber", &"add_white")
	_dim_meshes[&"muzzle"] = VfxMeshes.star(&"add_amber", &"add_white", DIM)
	_lit_meshes[&"burst"] = VfxMeshes.star(&"add_red", &"add_amber")
	_dim_meshes[&"burst"] = VfxMeshes.star(&"add_red", &"add_amber", DIM)
	_lit_meshes[&"ring"] = VfxMeshes.ring(0.9, 40, &"add_cyan", &"add_white")
	_dim_meshes[&"ring"] = VfxMeshes.ring(0.9, 40, &"add_cyan", &"add_white", DIM)
	_muzzles = _make_pool("Muzzle", _lit_meshes[&"muzzle"], MUZZLE_CAP, VfxPool.Mode.BILLBOARD, bounds)
	_sparks = _make_pool("Sparks", VfxMeshes.streak(&"emit_amber"), SPARK_CAP, VfxPool.Mode.STREAK, bounds)
	_debris = _make_pool(
		"Debris", VfxMeshes.cube(&"gunmetal"), BURST_CAP * DEBRIS_PER_BURST, VfxPool.Mode.DEBRIS, bounds
	)
	_bursts = _make_pool("Bursts", _lit_meshes[&"burst"], BURST_CAP, VfxPool.Mode.BILLBOARD, bounds)
	_dust = _make_pool("Dust", VfxMeshes.puff(&"add_white", 0.16), DUST_CAP, VfxPool.Mode.BILLBOARD, bounds)
	_rings = _make_pool("EmpRings", _lit_meshes[&"ring"], RING_CAP, VfxPool.Mode.FLAT, bounds)
	_texts = FloatingTexts.new()
	_texts.setup()
	add_child(_texts)
	_auras = VfxAuras.new()
	_auras.setup(_arena)
	add_child(_auras)
	_flash = ScreenFlash.new()
	_flash.setup()
	add_child(_flash)
	_chaos = FxChaos.new()
	_chaos.setup(self, content, actors, _sparks, bounds, _rng)
	_pools.append_array(_chaos.pools())
	if _actors != null:
		_actors.footfall.connect(_on_footfall)
	set_quality(_quality)


func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim
	_flash_cd = 0.0
	Events.shot_fired.connect(_on_shot_fired)
	Events.enemy_died_at.connect(_on_enemy_died_at)
	Events.core_hit.connect(_on_core_hit)
	Events.ability_activated.connect(_on_ability_activated)
	_chaos.bind()


func unbind() -> void:
	if Events.shot_fired.is_connected(_on_shot_fired):
		Events.shot_fired.disconnect(_on_shot_fired)
	if Events.enemy_died_at.is_connected(_on_enemy_died_at):
		Events.enemy_died_at.disconnect(_on_enemy_died_at)
	if Events.core_hit.is_connected(_on_core_hit):
		Events.core_hit.disconnect(_on_core_hit)
	if Events.ability_activated.is_connected(_on_ability_activated):
		Events.ability_activated.disconnect(_on_ability_activated)
	_sim = null
	for p: VfxPool in _pools:
		p.clear()
	if _chaos != null:
		_chaos.unbind()
	if _texts != null:
		_texts.clear()
		_auras.clear()
		_flash.clear()


func _exit_tree() -> void:
	unbind()


func render(_alpha: float, delta: float) -> void:
	if _sim == null:
		return
	var dt: float = clampf(delta, 0.0, 0.1)
	_update_facing()
	_flash_cd = maxf(0.0, _flash_cd - dt)
	for p: VfxPool in _pools:
		p.step(dt)
	_chaos.step(dt, _facing)
	_texts.step(dt)
	_flash.step(dt)
	var absorb: float = maxf(_content.abilities[Ids.AB_SHIELD].absorb, 0.001)
	var shield_frac: float = clampf(_sim.shield_hp / absorb, 0.0, 1.0)
	var warden_pos: Vector3 = Vector3(_sim.warden.x, 0.0, _sim.warden.z)
	_auras.update(dt, shield_frac, _sim.abilities.is_active(Ids.AB_OVERDRIVE), warden_pos)


func set_quality(tier: int) -> void:
	_quality = VisualQuality.from_setting(tier)
	_texts.set_cap(TEXT_CAP_BY_TIER[_quality])
	_auras.set_quality(_quality)
	_chaos.set_quality(_quality)


## Reduced Flash (GDD 10.3): no full-screen flash, dimmer muzzle, burst and EMP flashes, no shimmer.
func set_reduced_flash(on: bool) -> void:
	_reduced = on
	_flash.set_reduced(on)
	_auras.set_reduced(on)
	_chaos.set_reduced(on)
	var meshes: Dictionary[StringName, ArrayMesh] = _dim_meshes if on else _lit_meshes
	_muzzles.set_mesh(meshes[&"muzzle"])
	_bursts.set_mesh(meshes[&"burst"])
	_rings.set_mesh(meshes[&"ring"])


# --- accessors for tests and tooling ---


func tracer_count() -> int:
	return _tracers.live_count()


func tracer_capacity() -> int:
	return _tracers.capacity


func spark_count() -> int:
	return _sparks.live_count()


func debris_count() -> int:
	return _debris.live_count()


func burst_count() -> int:
	return _bursts.live_count()


func muzzle_count() -> int:
	return _muzzles.live_count()


func dust_count() -> int:
	return _dust.live_count()


func ring_count() -> int:
	return _rings.live_count()


func text_count() -> int:
	return _texts.live_count()


## The chaos effects of the variety milestone (blasts, arcs, telegraphs, pools): tests and tooling read their pools through it.
func chaos() -> FxChaos:
	return _chaos


func floating_texts() -> FloatingTexts:
	return _texts


func screen_flash() -> ScreenFlash:
	return _flash


func auras() -> VfxAuras:
	return _auras


## Alpha of the muzzle flash material (drops under Reduced Flash).
func flash_alpha() -> float:
	return _muzzles.mesh_alpha()


func is_reduced_flash() -> bool:
	return _reduced


func quality() -> int:
	return _quality


# --- event handlers ---


func _on_shot_fired(source: int, target_id: int) -> void:
	if _sim == null or _actors == null:
		return
	var from: Vector3 = _origin_of(source)
	if not from.is_finite():
		return
	var hit: Vector3 = _actors.enemy_hit_position(target_id)
	var has_target: bool = hit.is_finite()
	if not has_target:
		hit = _aim_point(source)
	var overdrive: bool = source == DamageSource.Id.WARDEN and _sim.abilities.is_active(Ids.AB_OVERDRIVE)
	var life: float = TRACER_LIFE_OVERDRIVE_S if overdrive else TRACER_LIFE_S
	var _tracer: int = _tracers.spawn(from, hit, 0.17, 0.06, life)
	var size: float = 0.45 if _reduced else 0.85
	var _flash_slot: int = _muzzles.spawn(from, Vector3.ZERO, size, size * 0.2, 0.07, _rng.randf_range(0.0, TAU))
	if has_target:
		_impact_sparks(hit, from - hit, SPARKS_PER_HIT[_quality], 1.0)


func _on_enemy_died_at(_enemy_id: int, kind: StringName, x: float, z: float, scrap: int) -> void:
	if _sim == null:
		return
	var index: int = Ids.enemy_index(kind)
	if index < 0:
		return
	var def: EnemyDef = _content.enemies[index]
	var heavy: bool = def.is_boss
	var mini: bool = def.is_mini()  # a mini dies small: a pinprick, one stone, no floating Scrap text (40 of them would hide the swarm)
	var center: Vector3 = Vector3(x, def.visual_height_m * 0.45, z)
	var burst_n: int = 3 if heavy else 1
	var burst_life: float = 0.5 if heavy else (0.16 if mini else 0.26)
	var burst_size: float = def.radius * (2.6 if heavy else 3.2) + 0.3
	if mini:
		burst_size = 0.4
	for _b: int in burst_n:
		var off: Vector3 = Vector3.ZERO
		if heavy:
			off = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 1.0), _rng.randf_range(-1.0, 1.0))
			off *= def.radius
		var _burst: int = _bursts.spawn(
			center + off, Vector3.ZERO, burst_size, burst_size * 0.25, burst_life, _rng.randf_range(0.0, TAU)
		)
	var pieces: int = 1 if mini else DEBRIS_PER_DEATH[_quality] * (4 if heavy else 1)
	var scale_up: float = 2.4 if heavy else 1.0
	for _k: int in pieces:
		var ang: float = _rng.randf_range(0.0, TAU)
		var out: float = _rng.randf_range(1.2, 3.6) * (1.4 if heavy else 1.0)
		var vel: Vector3 = Vector3(cos(ang) * out, _rng.randf_range(2.5, 5.0), sin(ang) * out)
		var s0: float = _rng.randf_range(0.08, 0.16) * scale_up
		var _piece: int = _debris.spawn(center, vel, s0, 0.0, _rng.randf_range(0.6, 1.0), _rng.randf_range(-9.0, 9.0))
	if not mini:
		_texts.spawn("+%d" % scrap, Vector3(x, def.visual_height_m + 0.35, z), 1.5 if heavy else 1.0, _text_color)


func _on_core_hit(enemy_id: int, _kind: StringName, hp_damage: float, absorbed: float) -> void:
	if _sim == null:
		return
	var core: Vector3 = Vector3(_arena.core_x, 0.0, _arena.core_z)
	var dir: Vector3 = Vector3.RIGHT
	if _actors != null:
		var e: Vector3 = _actors.enemy_world_position(enemy_id)
		if e.is_finite():
			var flat: Vector3 = Vector3(e.x - core.x, 0.0, e.z - core.z)
			if flat.length() > 0.01:
				dir = flat.normalized()
	var at: Vector3 = core + dir * _arena.core_radius + Vector3(0.0, 1.1, 0.0)
	if hp_damage > 0.0:
		var _flash_slot: int = _muzzles.spawn(at, Vector3.ZERO, 0.8, 0.15, 0.1, _rng.randf_range(0.0, TAU))
		_impact_sparks(at, dir, SPARKS_PER_HIT[_quality], 1.4)
		if hp_damage >= 25.0 and _flash_cd <= 0.0:
			_flash_cd = CORE_FLASH_COOLDOWN_S
			_flash.trigger(_content.tokens.color(&"chorus_red"), 0.14, 0.28)
	if absorbed > 0.0:
		_auras.pulse()


func _on_ability_activated(ability_id: StringName) -> void:
	if _sim == null or ability_id != Ids.ABILITIES[Ids.AB_EMP]:
		return
	var origin: Vector3 = Vector3(_sim.warden.x, 0.08, _sim.warden.z)
	var _ring: int = _rings.spawn(origin, Vector3.ZERO, 1.0, EMP_RING_RADIUS_M, EMP_RING_S)
	_flash.trigger(Color(0.75, 0.96, 1.0), 0.32, 0.3)


## Boss footfall dust: pale puffs and a few stones kicked up. Not on LOW.
func _on_footfall(world_pos: Vector3, weight: float) -> void:
	if _sim == null or _quality == VisualQuality.Tier.LOW:
		return
	for _p: int in 2 + _quality:
		var off: Vector3 = Vector3(_rng.randf_range(-1.1, 1.1), 0.25, _rng.randf_range(-1.1, 1.1)) * weight
		var life: float = _rng.randf_range(0.55, 0.85)
		var _puff: int = _dust.spawn(world_pos + off, Vector3.ZERO, 0.4 * weight, 1.5 * weight, life)
	for _s: int in _quality + 1:
		var ang: float = _rng.randf_range(0.0, TAU)
		var vel: Vector3 = Vector3(cos(ang) * 2.2, _rng.randf_range(1.5, 3.0), sin(ang) * 2.2)
		var spin: float = _rng.randf_range(-8.0, 8.0)
		var _stone: int = _debris.spawn(world_pos + Vector3(0.0, 0.2, 0.0), vel, 0.14 * weight, 0.0, 0.6, spin)


# --- helpers ---


## `n` sparks leaving `at`, mostly along `away`; `power` scales their length and speed.
func _impact_sparks(at: Vector3, away: Vector3, n: int, power: float) -> void:
	var flat: Vector3 = Vector3(away.x, 0.0, away.z)
	var base: Vector3 = Vector3.LEFT
	if flat.length() > 0.01:
		base = flat.normalized()
	for _i: int in n:
		var jitter: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * 0.8
		var dir: Vector3 = (base * _rng.randf_range(0.3, 1.0) + jitter).normalized()
		var vel: Vector3 = dir * _rng.randf_range(3.5, 7.0) * power + Vector3(0.0, _rng.randf_range(1.5, 3.5), 0.0)
		var life: float = _rng.randf_range(0.18, 0.3)
		var _spark: int = _sparks.spawn(at, vel, 0.5 * power, 0.06, life)


func _origin_of(source: int) -> Vector3:
	if source == DamageSource.Id.WARDEN:
		return _actors.warden_muzzle_position()
	return _actors.turret_muzzle_position(source - DamageSource.Id.TURRET_0)


## Where a shot goes when its target is not in the view (already gone): the shooter's aim point.
func _aim_point(source: int) -> Vector3:
	if source == DamageSource.Id.WARDEN:
		return Vector3(_sim.warden.aim_x, 0.8, _sim.warden.aim_z)
	var pad: int = clampi(source - DamageSource.Id.TURRET_0, 0, _sim.turrets.aim_x.size() - 1)
	return Vector3(_sim.turrets.aim_x[pad], 0.8, _sim.turrets.aim_z[pad])


## Camera-facing basis for the billboard pools: the camera basis turned so a quad's +Y faces the camera.
func _update_facing() -> void:
	var cam: Basis
	if _rig != null and _rig.camera != null and _rig.camera.is_inside_tree():
		cam = _rig.camera.global_transform.basis.orthonormalized()
	else:
		cam = Basis(Vector3.RIGHT, -deg_to_rad(_arena.pitch_down_deg)) * Basis(Vector3.UP, deg_to_rad(_arena.yaw_deg))
	var face: Basis = cam * Basis(Vector3.RIGHT, PI * 0.5)
	_muzzles.facing = face
	_bursts.facing = face
	_dust.facing = face
	_facing = face


func _make_pool(node_name: String, mesh_res: Mesh, cap: int, pool_mode: int, bounds: AABB) -> VfxPool:
	var pool: VfxPool = VfxPool.new()
	pool.setup(self, node_name, mesh_res, cap, pool_mode, bounds)
	_pools.append(pool)
	return pool
