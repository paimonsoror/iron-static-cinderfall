class_name FxZones
extends RefCounted
## The zones that follow enemies (VARIETY_SPEC 10.3, 12.3 `fx_ward_ring`, `fx_tether`; V4-X): a dashed red ring under every ward and aura
## (shieldbearer ward, jammer aura, elite personal ward, overclocker) and a thin red line for every tether (a reclaimer to the damaged
## enemies it heals, a MAGNETIC elite to the shooters it forces). The data decides what exists (`ward_radius` and `aura_radius` of the enemy
## defs, the affix mask of `EnemyExtState`); the view reads the sim every frame and never writes it. The burning ground pools and the
## elite rings under elites are drawn elsewhere (`FxPools`, `ActorDecals`); the telegraph decals are `FxTelegraph`.
## Colour and shape (SPEC 5.6): none of these hurts the player's side, so they carry no hatch; they are red because they are CHORUS, and
## DASHED so the solid shrinking outline of a danger decal never reads alike. A static front takes every ward and aura down: no ring is
## drawn while the abilities are locked (`EventState.ability_lock_ticks`). A ward the sim reports broken (`ward_changed` at 0) loses its
## ring until the sim reports it back. Tier: 8 / 10 / 12 rings and 6 / 9 / 12 tether lines, importance first (shieldbearer wards, then
## jammer auras, personal wards, overclockers; reclaimer tethers, then magnetic ones); whatever does not fit is not drawn.

const RING_Y: float = 0.04
const RING_DASHES: int = 24
const RING_DUTY: float = 0.62
const RING_INNER: float = 0.93
const RING_INNER_CONTRAST: float = 0.84
const PERSONAL_WARD_M: float = 0.85
const OVERCLOCK_M: float = 4.0
const MAGNET_M: float = 12.0
const LINE_WIDTH_M: float = 0.07
const LINE_WIDTH_CONTRAST_M: float = 0.13
const LINE_FROM_Y: float = 1.1
const LINE_TO_Y: float = 0.7

enum Ring { WARD, AURA, PERSONAL, OVERCLOCK }

var rings: FxFollow = FxFollow.new()
var tethers: FxFollow = FxFollow.new()

var _ctx: FxContext
var _broken: Dictionary[int, bool] = {}  ## enemy id -> its ward is down
var _bit_warded: int = 0
var _bit_overclock: int = 0
var _bit_magnetic: int = 0
var _near: PackedInt32Array = PackedInt32Array([0, 0, 0])  ## the nearest damaged enemies of one reclaimer (store indices)
var _near_d: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
var _lit_ring: ArrayMesh
var _bold_ring: ArrayMesh


func setup(parent: Node3D, bounds: AABB, ctx: FxContext) -> void:
	_ctx = ctx
	_lit_ring = VfxMeshes.dashed_ring(RING_INNER, RING_DASHES, RING_DUTY, &"add_red")
	_bold_ring = VfxMeshes.dashed_ring(RING_INNER_CONTRAST, RING_DASHES, RING_DUTY, &"add_red")
	rings.setup(parent, "WardRings", _lit_ring, VisualQuality.WARD_RING_CAP[VisualQuality.Tier.HIGH], bounds)
	tethers.setup(parent, "Tethers", VfxMeshes.tracer(&"add_red"), VisualQuality.TETHER_CAP[VisualQuality.Tier.HIGH], bounds)
	_bit_warded = _affix_bit(&"aff_warded")
	_bit_overclock = _affix_bit(&"aff_overclock")
	_bit_magnetic = _affix_bit(&"aff_magnetic")
	set_quality(ctx.tier)


func bind() -> void:
	_broken.clear()
	if not Events.ward_changed.is_connected(_on_ward_changed):
		Events.ward_changed.connect(_on_ward_changed)


func unbind() -> void:
	if Events.ward_changed.is_connected(_on_ward_changed):
		Events.ward_changed.disconnect(_on_ward_changed)
	_broken.clear()
	rings.clear()
	tethers.clear()


func set_quality(tier: int) -> void:
	rings.set_limit(VisualQuality.ward_rings(tier))
	tethers.set_limit(VisualQuality.tethers(tier))


## High Contrast thickens the ring band and the tether line.
func set_contrast(on: bool) -> void:
	rings.set_mesh(_bold_ring if on else _lit_ring)


## Once per rendered frame: rebuilds the rings and the lines from the sim.
func step() -> void:
	rings.begin()
	tethers.begin()
	var sim: SimWorld = _ctx.sim
	if sim != null and sim.content.is_variety():
		if sim.events_state.ability_lock_ticks <= 0:
			for kind: int in [Ring.WARD, Ring.AURA, Ring.PERSONAL, Ring.OVERCLOCK]:
				_add_rings(sim, kind)
		_add_reclaimer_tethers(sim)
		if _bit_magnetic >= 0:
			_add_magnetic_tethers(sim)
	rings.end()
	tethers.end()


func is_broken(enemy_id: int) -> bool:
	return _broken.has(enemy_id)


func live_count() -> int:
	return rings.drawn() + tethers.drawn()


func _add_rings(sim: SimWorld, kind: int) -> void:
	var st: EnemyStore = sim.enemies
	for i: int in st.high_water:
		if st.alive[i] == 0:
			continue
		var radius: float = _ring_radius(sim, i, kind)
		if radius <= 0.0:
			continue
		var at: Vector3 = _ctx.enemy_at(st.id[i])
		if at.is_finite() and not rings.add_ring(Vector3(at.x, RING_Y, at.z), radius):
			return  # the pool is full: the rest of this kind, and the kinds after it, are not drawn


func _ring_radius(sim: SimWorld, i: int, kind: int) -> float:
	var def: EnemyDef = _ctx.content.enemies[sim.enemies.type[i]]
	var up: bool = not _broken.has(sim.enemies.id[i])
	var mask: int = sim.ext.affix_mask[i]
	match kind:
		Ring.WARD:
			return def.beh(&"ward_radius") if up else 0.0
		Ring.AURA:
			return def.beh(&"aura_radius")
		Ring.PERSONAL:
			return PERSONAL_WARD_M if up and _bit_warded >= 0 and (mask & (1 << _bit_warded)) != 0 else 0.0
		_:
			return OVERCLOCK_M if _bit_overclock >= 0 and (mask & (1 << _bit_overclock)) != 0 else 0.0


## A reclaimer is tethered to up to `tether_count` damaged enemies (not bosses) within `tether_range`, the nearest first.
func _add_reclaimer_tethers(sim: SimWorld) -> void:
	var st: EnemyStore = sim.enemies
	var def: EnemyDef = _ctx.content.enemies[Ids.EN_RECLAIMER]
	var count: int = clampi(roundi(def.beh(&"tether_count", 3.0)), 0, _near.size())
	var reach: float = def.beh(&"tether_range", 6.0)
	for i: int in st.high_water:
		if st.alive[i] == 0 or st.type[i] != Ids.EN_RECLAIMER:
			continue
		var from: Vector3 = _ctx.enemy_at(st.id[i])
		if not from.is_finite():
			continue
		var found: int = 0
		for j: int in st.high_water:
			if j == i or st.alive[j] == 0 or st.hp[j] >= st.max_hp[j] or _ctx.content.enemies[st.type[j]].is_boss:
				continue
			var d: float = Vector2(st.x[j] - st.x[i], st.z[j] - st.z[i]).length()
			if d <= reach:
				found = _keep_nearest(found, count, j, d)
		for k: int in found:
			var to: Vector3 = _ctx.enemy_at(st.id[_near[k]])
			if to.is_finite() and not tethers.add_line(from + Vector3(0.0, LINE_FROM_Y, 0.0), to + Vector3(0.0, LINE_TO_Y, 0.0), _line_width()):
				return


## Inserts store index `j` at distance `d` into the sorted nearest list (size `found` of at most `count`); returns the new size.
func _keep_nearest(found: int, count: int, j: int, d: float) -> int:
	if count == 0:
		return 0
	var at: int = found
	while at > 0 and _near_d[at - 1] > d:
		at -= 1
	if at >= count:
		return found
	var last: int = mini(found, count - 1)
	for s: int in range(last, at, -1):
		_near[s] = _near[s - 1]
		_near_d[s] = _near_d[s - 1]
	_near[at] = j
	_near_d[at] = d
	return mini(found + 1, count)


## A MAGNETIC elite draws a line from every shooter within 12 m (the Warden and the active turrets): they must target it.
func _add_magnetic_tethers(sim: SimWorld) -> void:
	var st: EnemyStore = sim.enemies
	for i: int in st.high_water:
		if st.alive[i] == 0 or (sim.ext.affix_mask[i] & (1 << _bit_magnetic)) == 0:
			continue
		var to: Vector3 = _ctx.enemy_at(st.id[i])
		if not to.is_finite():
			continue
		var shooters: Array[Vector3] = [_ctx.actors.warden_muzzle_position()]
		for pad: int in sim.turrets.active.size():
			if sim.turrets.active[pad] == 1:
				shooters.append(_ctx.actors.turret_muzzle_position(pad))
		for from: Vector3 in shooters:
			if from.is_finite() and Vector2(from.x - to.x, from.z - to.z).length() <= MAGNET_M:
				if not tethers.add_line(from, to + Vector3(0.0, LINE_TO_Y, 0.0), _line_width()):
					return


func _line_width() -> float:
	return LINE_WIDTH_CONTRAST_M if _ctx.contrast else LINE_WIDTH_M


func _affix_bit(affix_id: StringName) -> int:
	for a: AffixDef in _ctx.content.affixes:
		if a.id == affix_id:
			return a.index
	return -1


func _on_ward_changed(enemy_id: int, fraction: float) -> void:
	if fraction <= 0.0:
		_broken[enemy_id] = true
	else:
		var _gone: bool = _broken.erase(enemy_id)
