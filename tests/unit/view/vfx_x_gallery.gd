extends Node
## V4-X capture helper (not a test suite): the real BattleView with a throwaway SimWorld in the game camera, and the events of one show fired on a
## script of frames, so the effects, zones and event warnings can be looked at the way the game draws them (and counted: `--fx=0` is the same frame
## with no effect, the other half of a legibility pair).
##   -Scene "res://tests/unit/view/vfx_x_gallery.tscn --show=warnings|freight|strike|zones|air|lance|boss|crowd" -Frames <n> -Size 1080x2400
##   --quality=0|1|2  --high-contrast  --reduced-flash  --fx=0  --look=current|stylised
## The puppet of the debug sandbox is not used: every number here is pushed through `Events` exactly as the relay would, one frame per 1/60 s
## (a capture frame N is second N/60 of the show). Nothing here is part of the game.

var _view: BattleView
var _world: SimWorld
var _content: ContentSet
var _show: String = "warnings"
var _frame: int = 0
var _fx: bool = true
var _ids: Dictionary[String, int] = {}  ## named enemies of the show -> enemy id


func _ready() -> void:
	_content = Content.db
	var tier: int = VisualQuality.Tier.HIGH
	var contrast: bool = false
	var reduced: bool = false
	var look: int = -1
	for raw: String in DebugArgs.expand(OS.get_cmdline_user_args()):
		var kv: PackedStringArray = raw.split("=", true, 1)
		var value: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"--show":
				_show = value
			"--quality":
				tier = clampi(value.to_int(), 0, 2)
			"--high-contrast":
				contrast = true
			"--reduced-flash":
				reduced = true
			"--fx":
				_fx = value != "0"
			"--look":
				look = LookDevStyle.from_name(value)
	var packed: PackedScene = load("res://src/view/battle_view.tscn") as PackedScene
	_view = packed.instantiate() as BattleView
	add_child(_view)
	_view.setup(_content)
	_view.set_quality(tier)
	_view.set_high_contrast(contrast)
	_view.set_reduced_flash(reduced)
	if look >= 0:
		_view.actor_layer.set_look(look)
		_view.arena_view.set_look(look)
	_world = SimWorld.new(SimConfig.create(_content, 1))
	_world.phase = GameState.Id.SPAWNING
	_place()
	_view.bind(_world)
	get_viewport().size_changed.connect(_refit)
	_refit()


func _process(_delta: float) -> void:
	_frame += 1
	if _fx:
		_script()
	_view.render(1.0, 1.0 / 60.0)


func _refit() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var top: float = HudLayout.top_band_px(size, Vector4.ZERO, _content.tokens)
	var bottom: float = HudLayout.bottom_band_px(size, Vector4.ZERO, _content.tokens)
	_view.fit_camera(size, top, bottom)


# ---------------------------------------------------------------- what stands in the yard


func _place() -> void:
	match _show:
		"warnings":
			_crowd(14, 0, Vector2(-1.0, 2.0), 5.0)
			_drums()
		"freight":
			_crowd(10, 0, Vector2(0.0, 3.0), 5.0)
			_drums()
		"strike":
			_crowd(18, 0, Vector2(-1.0, 2.5), 3.0)
		"zones":
			_zones()
		"air":
			_air()
		"lance":
			_lance()
		"boss":
			var boss: int = _enemy(Ids.EN_LANCE_PLATFORM, 6.0, 3.0)
			_world.boss.boss_id = _world.enemies.id[boss]
			_crowd(10, 0, Vector2(2.0, -2.0), 4.0)
		"crowd":
			_crowd(50, 40, Vector2(1.5, 0.5), 6.5)


func _enemy(type_index: int, x: float, z: float, hp_fraction: float = 1.0) -> int:
	var i: int = _world.spawn_enemy(type_index, x, z)
	if i < 0:
		return i
	_world.enemies.hp[i] = _world.enemies.max_hp[i] * hp_fraction
	_world.enemies.prev_x[i] = x
	_world.enemies.prev_z[i] = z
	_world.enemies.face_x[i] = -1.0
	_world.enemies.face_z[i] = 0.0
	return i


## `bodies` mixed bodies and `minis` motes on a deterministic spiral around `center`.
func _crowd(bodies: int, minis: int, center: Vector2, spread: float) -> void:
	var kinds: Array[int] = [Ids.EN_SKITTER, Ids.EN_SKITTER, Ids.EN_RUSHER, Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_BURSTER]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	for n: int in bodies + minis:
		var ang: float = float(n) * 2.399963
		var r: float = spread * sqrt((float(n) + 0.5) / float(bodies + minis))
		var at: Vector2 = center + Vector2(cos(ang) * r * 1.15, sin(ang) * r)
		at = Vector2(clampf(at.x, -9.0, 9.5), clampf(at.y, -14.0, 10.0))
		var kind: int = Ids.EN_MOTE if n >= bodies else kinds[n % kinds.size()]
		var _i: int = _enemy(kind, at.x + rng.randf_range(-0.2, 0.2), at.y + rng.randf_range(-0.2, 0.2))


func _drums() -> void:
	_world.hazards.d_point = PackedInt32Array([0, 3, 4])
	_world.hazards.d_alive = PackedInt32Array([1, 1, 1])


func _zones() -> void:
	var shield_a: int = _enemy(Ids.EN_SHIELDBEARER, 2.0, -5.0)
	var _shield_b: int = _enemy(Ids.EN_SHIELDBEARER, 6.5, -1.0)
	var _jam: int = _enemy(Ids.EN_JAMMER, 2.0, 6.0)
	var rec: int = _enemy(Ids.EN_RECLAIMER, 7.5, 2.0)
	for k: int in 4:
		var _d: int = _enemy(Ids.EN_SKITTER, 4.5 + float(k) * 0.9, 1.0 + float(k % 2) * 1.6, 0.45)
	var warded: int = _enemy(Ids.EN_RUSHER, -1.0, -3.0)
	var magnetic: int = _enemy(Ids.EN_HOLLOW, -2.0, 1.0)
	var over: int = _enemy(Ids.EN_SKITTER, 0.5, -8.0)
	_world.ext.affix_mask[warded] = 1 << _bit(&"aff_warded")
	_world.ext.affix_mask[magnetic] = 1 << _bit(&"aff_magnetic")
	_world.ext.affix_mask[over] = 1 << _bit(&"aff_overclock")
	_world.turrets.active[0] = 1
	_ids["shield"] = _world.enemies.id[shield_a]
	_ids["rec"] = _world.enemies.id[rec]


func _air() -> void:
	var target: int = _enemy(Ids.EN_SKITTER, -3.0, -1.5)
	for k: int in 8:
		var _s: int = _enemy(Ids.EN_SKITTER, -3.0 + float(k % 4) * 1.1, -1.5 - float(floori(float(k) / 4.0)) * 1.1)
	var spitter: int = _enemy(Ids.EN_SPITTER, 4.5, 3.0)
	_world.ext.aux_cd[spitter] = 100
	_world.warden.weapon_index = Ids.WP_CUTTING_TORCH
	_world.arsenal.beam_target = _world.enemies.id[target]
	_world.arsenal.beam_hits = 14
	_world.warden.aim_x = -3.0
	_world.warden.aim_z = -1.5
	_ids["target"] = _world.enemies.id[target]


func _lance() -> void:
	for k: int in 5:
		var _s: int = _enemy(Ids.EN_SKITTER, -3.0 + float(k) * 0.2, 1.0 - float(k) * 1.6)
	_world.warden.weapon_index = Ids.WP_RAIL_LANCE
	_world.warden.aim_x = -3.0
	_world.warden.aim_z = 1.0
	_world.arsenal.charge_left = 90
	_world.arsenal.charge_x = -2.5
	_world.arsenal.charge_z = -4.0


func _bit(affix_id: StringName) -> int:
	for a: AffixDef in _content.affixes:
		if a.id == affix_id:
			return a.index
	return 0


# ---------------------------------------------------------------- what happens, frame by frame


func _script() -> void:
	match _show:
		"warnings":
			if _frame == 1:
				Events.event_warned.emit(&"runaway_freight", 300, 0.0, -6.5)
				Events.event_warned.emit(&"floor_breach", 300, 2.5, -2.0)
				Events.event_warned.emit(&"floor_breach", 300, 6.0, 2.5)
				Events.event_warned.emit(&"floor_breach", 300, 5.0, -4.5)
				Events.event_warned.emit(&"recount", 300, 10.8, 0.0)
		"freight":
			if _frame == 1:
				Events.event_warned.emit(&"runaway_freight", 300, 0.0, -6.5)
			if _frame == 20:
				Events.event_started.emit(&"runaway_freight")
		"strike":
			if _frame == 1:
				Events.event_warned.emit(&"static_front", 360, 0.0, 0.0)
				Events.event_warned.emit(&"power_surge", 300, 0.0, 0.0)
				Events.event_warned.emit(&"deadfall_strike", 120, -1.0, 2.5)
				Events.delayed_hit.emit(HazardState.K_STRIKE, -1.0, 2.5, 120)
			if _frame == 121:
				Events.area_blast.emit(HazardState.K_STRIKE, -1.0, 2.5, 4.0)
		"zones":
			if _frame == 1:
				Events.ward_changed.emit(_ids["shield"], 1.0)
		"air":
			if _frame % 70 == 15:
				Events.delayed_hit.emit(HazardState.K_SHELL, -3.0, -2.0, 42)
				for k: int in 6:
					Events.delayed_hit.emit(HazardState.K_MISSILE, -4.0 + float(k) * 1.2, -2.5, 30)
				Events.delayed_hit.emit(HazardState.K_BOLT, _content.arena.core_x + 1.2, _content.arena.core_z, 48)
			if _frame % 70 == 20:
				Events.shot_fired.emit(DamageSource.Id.WARDEN, _ids.get("target", 0))
		"lance":
			if _frame == 91:
				_world.arsenal.charge_left = 0
				Events.shot_fired.emit(DamageSource.Id.WARDEN, _first_enemy())
		"boss":
			if _frame == 5:
				Events.boss_telegraph.emit(0, 180)
		"crowd":
			_chain()


func _first_enemy() -> int:
	for i: int in _world.enemies.high_water:
		if _world.enemies.alive[i] == 1:
			return _world.enemies.id[i]
	return 0


## Six blasts through the crowd, one every 6 ticks from frame 30: the moment a chain is at its loudest is about frame 52.
func _chain() -> void:
	var since: int = _frame - 30
	if since < 0 or since % 6 != 0 or floori(float(since) / 6.0) >= 6:
		return
	var k: int = floori(float(since) / 6.0)
	var at: Vector2 = Vector2(5.5 - float(k) * 1.15, 0.5 + float(k % 3) * 1.4 - 1.4)
	Events.area_blast.emit(HazardState.K_BLAST, at.x, at.y, 2.6)
	if k == 0:
		Events.area_blast.emit(HazardState.K_STRIKE, 2.0, 0.5, 4.0)
