class_name FxBoss
extends RefCounted
## The telegraphs of a boss attack (VARIETY_SPEC 6, 12.3; V4-X), drawn on the ground from `boss_telegraph(attack, ticks)`. The sim says that
## an attack is coming and in how many ticks; WHICH boss it is comes from the store (`BossState.boss_id`, else the first living boss), so the
## look is the boss's, whatever number the attack has:
##   Lance Platform  a RED HATCHED strip from the boss to the core and a frame that closes in on it for the whole charge, then at the end of
##                   the charge a red-white beam along the same strip for 0.3 s (the shot the Shield absorbs or the EMP cancels);
##   Tremor Rig      a red ring that expands from the rig over the wind-up of its stomp (1.5 s);
##   Siege Hulk      a red hatched lane from the Hulk toward the core (the charge of the overclocked variant);
##   anything else   a red ring that closes in on the boss (the Brood Carrier's hatches, a phase pulse).
## All of it hurts the player's side (the core, the turrets, the magazine), so it is red and hatched where it covers ground, and it is NEVER
## tier-gated and never removed by Reduced Flash (a telegraph is information, not a flash). The strips are the telegraph pools of `FxTelegraph`
## (`lanes_red`, `bands`) plus one hatched strip pool for the long thin lance (the hatch stripes keep square at its aspect of 14).

const LANCE_HALF_WIDTH_M: float = 0.55
const LANCE_ASPECT: float = 14.0
const FIRE_LIFE_S: float = 0.3
const FIRE_WIDTH_M: float = 0.9
const STOMP_RADIUS_M: float = 9.0
const STOMP_START_M: float = 1.0
const PULSE_RADIUS_M: float = 2.2
const Y: float = 0.052
const FIRE_Y: float = 1.2

var lance_hatch: VfxPool
var fire: VfxPool

var started: int = 0  ## telegraphs drawn (tests, reports)

var _ctx: FxContext
var _tele: FxTelegraph
var _fire_in: float = -1.0
var _fire_from: Vector3 = Vector3.ZERO
var _fire_to: Vector3 = Vector3.ZERO


func setup(parent: Node3D, bounds: AABB, ctx: FxContext, decals: FxTelegraph) -> void:
	_ctx = ctx
	_tele = decals
	lance_hatch = VfxPool.new()
	lance_hatch.setup(parent, "LanceHatch", VfxMeshes.hatch_strip(&"hatch_red", LANCE_ASPECT), 2, VfxPool.Mode.STRIP, bounds)
	fire = VfxPool.new()
	fire.setup(parent, "BossBeam", VfxMeshes.bolt(&"add_red", &"add_white"), 2, VfxPool.Mode.BEAM, bounds)


func pools() -> Array[VfxPool]:
	return [lance_hatch, fire]


func bind() -> void:
	if not Events.boss_telegraph.is_connected(telegraph):
		Events.boss_telegraph.connect(telegraph)


func unbind() -> void:
	if Events.boss_telegraph.is_connected(telegraph):
		Events.boss_telegraph.disconnect(telegraph)
	_fire_in = -1.0


## `boss_telegraph(attack, ticks)`: the warning of the living boss's attack.
func telegraph(_attack: int, ticks: int) -> void:
	var sim: SimWorld = _ctx.sim
	if sim == null or not sim.content.is_variety():
		return
	var index: int = _boss_index(sim)
	if index < 0:
		return
	var at: Vector3 = _ctx.enemy_at(sim.enemies.id[index])
	if not at.is_finite():
		return
	var life: float = maxf(float(ticks) * SimWorld.DT, 0.05)
	var arena: ArenaDef = _ctx.content.arena
	var core: Vector3 = Vector3(arena.core_x, 0.0, arena.core_z)
	var flat: Vector3 = Vector3(at.x, 0.0, at.z)
	started += 1
	match sim.enemies.type[index]:
		Ids.EN_LANCE_PLATFORM:
			_lane_to(flat, core, life, true)
			_fire_from = Vector3(flat.x, FIRE_Y, flat.z)
			_fire_to = Vector3(core.x, FIRE_Y, core.z)
			_fire_in = life
		Ids.EN_TREMOR_RIG:
			var _ring: int = _tele.rings_red.spawn(Vector3(flat.x, Y, flat.z), Vector3.ZERO, STOMP_START_M, STOMP_RADIUS_M, life)
		Ids.EN_HULK:
			_lane_to(flat, core, life, false)
		_:
			var _pulse: int = _tele.rings_red.spawn(Vector3(flat.x, Y, flat.z), Vector3.ZERO, PULSE_RADIUS_M * FxTelegraph.CONTRACT, PULSE_RADIUS_M, life)


## Once per rendered frame: the shot of a Lance Platform leaves when its charge ends.
func step(delta: float) -> void:
	if _fire_in < 0.0:
		return
	_fire_in -= delta
	if _fire_in <= 0.0:
		_fire_in = -1.0
		var _slot: int = fire.spawn(_fire_from, _fire_to, FIRE_WIDTH_M, FIRE_WIDTH_M * 0.3, FIRE_LIFE_S)


func live_count() -> int:
	return lance_hatch.live_count() + fire.live_count()


## A red hatched strip from `from` to `to` that closes in on its own width over `life`; `thin` is the long lance, else a lane that is as wide as
## its eighth.
func _lane_to(from: Vector3, to: Vector3, life: float, thin: bool) -> void:
	var span: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length: float = span.length()
	if length < 0.5:
		return
	var mid: Vector3 = (from + to) * 0.5
	var yaw: float = atan2(-span.z, span.x)
	var half_len: float = length * 0.5
	var half_width: float = LANCE_HALF_WIDTH_M if thin else half_len / FxTelegraph.BAND_ASPECT
	var fill: VfxPool = lance_hatch if thin else _tele.bands
	var _fill: int = fill.spawn(Vector3(mid.x, FxTelegraph.HATCH_Y, mid.z), Vector3(half_len, 0.0, 0.0), half_width, half_width, life, yaw)
	var frame_at: Vector3 = Vector3(mid.x, FxTelegraph.LANE_Y, mid.z)
	var _outline: int = _tele.lanes_red.spawn(frame_at, Vector3(half_len, 0.0, 0.0), half_width, half_width, life, yaw)
	var _closing: int = _tele.lanes_red.spawn(frame_at, Vector3(half_len, 0.0, 0.0), half_width * FxTelegraph.LANE_CLOSE, half_width, life, yaw)


## The living boss: the one `BossState` names, else the first living enemy whose def says boss.
func _boss_index(sim: SimWorld) -> int:
	var st: EnemyStore = sim.enemies
	var named: int = st.index_of(sim.boss.boss_id)
	if named >= 0:
		return named
	for i: int in st.high_water:
		if st.alive[i] == 1 and _ctx.content.enemies[st.type[i]].is_boss:
			return i
	return -1
