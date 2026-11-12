extends Node
## Look-dev sandbox (W3-C): the real BattleView and SimPuppet of the view sandbox (real arena, real game camera, the
## puppet's 10 to 50 enemies), plus a look switch for the Warden, a zoomed close-up camera, solo front/side views and
## measurement helpers. Capturable with tools/capture.ps1: `-Scene "res://src/debug/look_dev_sandbox.tscn --look=stylised --zoom=3"`.
##   --look=current|stylised|stylised_plus   the Warden look (default: the shipped one, CURRENT)
##   --quality=0|1|2                         LOW, MID, HIGH (default MID)
##   --zoom=<factor>                         top-down close-up on the Warden at the game camera's pitch (default 1 = the game)
##   --view=game|close|front|side|back|three camera (front, side, back and three-quarter are low perspective cameras that
##                                           follow the Warden's yaw; add --solo to hide the enemies)
##   --solo                                  hide the enemies, their blob shadows and health bars
##   --reload-pose                           hold the Warden's reload pose
##   --hide-warden                           draw everything but the Warden (pair with a normal capture: look_dev_legibility.gd)
##   --focus=warden|skitter|hollow_warden|rusher|siege_hulk|turret   the close-up and solo cameras follow that actor (W3-D);
##                                           with --solo and an enemy the other enemies and the Warden are hidden
##   --rollout=0|1                           0 keeps the turret and the enemies in CURRENT while the Warden is styled (cost measurement)
##   --scenario=hold10|hold28|hold50|boss    crowd (default hold28)   --seed=<n>
##   --render-size=1080x1920                 live runs: render in a SubViewport of that size (a desktop window cannot be taller
##                                           than the screen), so the GPU cost is that of a phone-sized frame
##   --msaa=0|2|4  --fxaa=0|1                force the anti-aliasing of the 3D viewport (default: by look and tier)
##   --glow=0|1                              force bloom off or on (cost measurement)   --tune=name:value,...  shader overrides
##   --debug-perf  --measure=<seconds>       PerfHud `[PERF]` lines every 5 s, quit after N seconds (live runs lift the fps cap)
##   --env=off|only:a,b|no:a,b               W3-E: switch single effects of the styled yard (EnvStyle names: floor wet props prop_shader
##                                           reactor spill vignette grade glow ripples flicker); `off` is today's yard with the styled Warden
##   --env-tune=name:value,...               W3-E: floor shader overrides (albedo_gain sheen_gain refl_gain puddle_lo puddle_hi crack_gain)
##   --cam-pitch=<deg> [--cam-persp=<fov>]   W3-E camera study: this pitch (orthographic, or perspective with that vertical fov) fitted into the
##                                           same HUD band; --cam-report logs the screen numbers (src/debug/env_cam_study.gd). Sandbox only.
## Keys: F8 cycles the look, F5 the quality tier, F9 the camera, F7 the perf overlay.
## In a capture the puppet steps a fixed 1/60 s per frame, so `--capture-frames=N` always shows second N/60.

const VIEWS: Array[String] = ["game", "close", "front", "side", "back", "three"]
const CAM_DISTANCE: float = 6.2
const CAM_FOV: float = 24.0
## Azimuth of the solo cameras around the Warden relative to its facing (degrees, 0 = in front) and elevation.
const CAM_AZIMUTH: Dictionary[String, float] = {"front": 0.0, "side": 90.0, "back": 180.0, "three": 38.0}
const CAM_ELEVATION_DEG: float = 11.0
## Arena nodes hidden in --solo so a low camera does not end up inside the reactor or a container.
const SOLO_HIDDEN: Array[String] = ["Core", "Props", "Decor", "LampHeads", "LampPools", "Pad0", "Pad1", "PadPool0", "PadPool1", "Rain"]

var _view: BattleView
var _puppet: SimPuppet
var _content: ContentSet
var _perf: PerfHud
var _perf_layer: CanvasLayer
var _fixed_step: bool = false
var _tier: int = VisualQuality.Tier.MID
var _look: int = LookDevStyle.Look.CURRENT
var _zoom: float = 1.0
var _mode: String = "game"
var _solo: bool = false
var _reload_pose: bool = false
var _hide_warden: bool = false
var _focus: LookActorsFocus = LookActorsFocus.new()
var _cam_pitch: float = 0.0
var _cam_persp: float = 0.0
var _report_frame: int = -1
var _frame: int = 0
var _top_px: float = 0.0
var _bottom_px: float = 0.0
var _measure_s: float = 0.0
var _elapsed: float = 0.0
var _extra_cam: Camera3D
var _host: Node
var _base_size: float = 1.0
var _base_xf: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	_content = Content.db
	var args: DebugArgs = DebugArgs.from_os()
	if args.cam_pitch > 0.0:
		_content.arena.pitch_down_deg = args.cam_pitch  # camera study: this process's copy of the arena, never data/
	_fixed_step = args.wants_capture()
	if not _fixed_step:
		Engine.max_fps = 0  # the 60 fps cap would hide headroom when measuring
	_host = self
	if args.render_size.x > 0 and not _fixed_step:
		var container: SubViewportContainer = SubViewportContainer.new()
		container.name = "RenderHost"
		add_child(container)
		var viewport: SubViewport = SubViewport.new()
		viewport.size = args.render_size
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		_host = viewport
	var packed: PackedScene = load("res://src/view/battle_view.tscn") as PackedScene
	_view = packed.instantiate() as BattleView
	_host.add_child(_view)
	_view.setup(_content)
	_tier = args.quality if args.quality >= 0 else VisualQuality.Tier.MID
	_view.set_quality(_tier)
	_view.set_high_contrast(args.high_contrast)
	_view.set_reduced_flash(args.reduced_flash)
	_puppet = SimPuppet.new()
	_host.add_child(_puppet)
	_puppet.setup(_content, args.scenario if args.scenario != "" else "hold28", args.run_seed if args.has_seed else 1)
	_view.bind(_puppet.world)
	_extra_cam = Camera3D.new()
	_extra_cam.name = "LookDevCamera"
	_extra_cam.fov = CAM_FOV
	_extra_cam.near = 0.3
	_extra_cam.far = 120.0
	_view.add_child(_extra_cam)
	_zoom = args.zoom
	_mode = args.view if VIEWS.has(args.view) else ("close" if _zoom > 1.01 else "game")
	if _mode == "close" and _zoom <= 1.01:
		_zoom = 3.0
	_solo = args.solo
	_reload_pose = args.reload_pose
	_hide_warden = args.hide_warden
	_focus.kind = args.focus if args.focus != "" else "warden"
	LookActorsStyle.rollout_override = args.rollout
	LookActorsStyle.small_baked_override = args.small_baked
	_measure_s = args.measure_s
	for pair: String in args.tune.split(",", false):
		var kv: PackedStringArray = pair.split(":")
		if kv.size() == 2 and kv[1].is_valid_float():
			LookDevMat.overrides[StringName(kv[0])] = kv[1].to_float()
	if args.env != "":
		EnvStyle.set_override(args.env)
	for pair2: String in args.env_tune.split(",", false):
		var kv2: PackedStringArray = pair2.split(":")
		if kv2.size() == 2 and kv2[1].is_valid_float():
			EnvGround.overrides[StringName(kv2[0])] = kv2[1].to_float()
	_cam_pitch = args.cam_pitch
	_cam_persp = args.cam_persp
	if args.cam_report:
		_report_frame = maxi(1, args.capture_frames - 6)
	LookDevStyle.glow_override = args.glow
	LookDevStyle.msaa_override = args.msaa
	LookDevStyle.fxaa_override = args.fxaa
	var started: int = Time.get_ticks_usec()
	_set_look(args.look if args.look >= 0 else LookDevStyle.current())
	Log.info("lookdev", "first set_look took %.1f ms (meshes and materials built)" % (float(Time.get_ticks_usec() - started) / 1000.0))
	if args.debug_perf:
		_add_perf_hud()
	_view.get_viewport().size_changed.connect(_refit)
	_refit()
	Log.info("lookdev", "look=%s quality=%s view=%s zoom=%.1f solo=%s viewport=%s window=%s screen=%s glow=%s" % [
		LookDevStyle.name_of(_look), VisualQuality.name_of(_tier), _mode, _zoom, str(_solo),
		str(_view.get_viewport().get_visible_rect().size), str(DisplayServer.window_get_size()),
		str(DisplayServer.screen_get_size()), str(_view.arena_view.glow_active())
	])


func _process(delta: float) -> void:
	var dt: float = SimPuppet.TICK_DT if _fixed_step else delta
	var alpha: float = _puppet.advance(dt)
	if _fixed_step:
		alpha = 1.0
	_view.render(alpha, dt)
	var warden: WardenView = _view.actor_layer.warden
	if _reload_pose:
		warden.debug_hold_reload(true)
	if _hide_warden:
		warden.visible = false  # the Warden still moves and fires, so the effects around it stay identical
	if _solo:
		_hide_enemies()
		if _focus.is_enemy():
			_focus.hide_others(_view.actor_layer)
			warden.visible = false
	_update_camera(warden)
	_elapsed += delta
	_frame += 1
	if _frame == _report_frame:
		Log.info("camreport", EnvCamStudy.report(_view.camera_rig.camera, _content.arena, _view.get_viewport().get_visible_rect().size, _top_px, _bottom_px, _puppet.world))
	if _measure_s > 0.0 and _elapsed >= _measure_s:
		get_tree().quit(0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F5:
			_tier = (_tier + 1) % 3
			_view.set_quality(_tier)
			Log.info("lookdev", "quality=%s" % VisualQuality.name_of(_tier))
		KEY_F7:
			if _perf == null:
				_add_perf_hud()
			else:
				_perf_layer.visible = not _perf_layer.visible
		KEY_F8:
			_set_look((_look + 1) % 3)
			Log.info("lookdev", "look=%s" % LookDevStyle.name_of(_look))
		KEY_F9:
			_mode = VIEWS[(VIEWS.find(_mode) + 1) % VIEWS.size()]
			if _mode == "close" and _zoom <= 1.01:
				_zoom = 3.0
			_refit()


func current_look() -> int:
	return _look


func view_mode() -> String:
	return _mode


func _set_look(look: int) -> void:
	_look = clampi(look, LookDevStyle.Look.CURRENT, LookDevStyle.Look.STYLISED_PLUS)
	LookDevStyle.set_current(_look)
	_view.actor_layer.set_look(_look)
	_view.arena_view.set_look(_look)


func _add_perf_hud() -> void:
	_perf_layer = CanvasLayer.new()
	_perf_layer.name = "PerfLayer"
	_perf_layer.layer = 100
	add_child(_perf_layer)
	_perf = PerfHud.new()
	_perf_layer.add_child(_perf)
	_perf.setup(Callable(self, "_alive_enemies"))
	_puppet.tick_sink = _perf.record_tick_usec


func _alive_enemies() -> int:
	return _puppet.world.alive_count()


## The game's own fit (HUD bands included), then the zoomed close-up on top of it when asked for.
func _refit() -> void:
	var size: Vector2 = _view.get_viewport().get_visible_rect().size
	var top: float = HudLayout.top_band_px(size, Vector4.ZERO, _content.tokens)
	var bottom: float = HudLayout.bottom_band_px(size, Vector4.ZERO, _content.tokens)
	_top_px = top
	_bottom_px = bottom
	_view.fit_camera(size, top, bottom)
	var cam: Camera3D = _view.camera_rig.camera
	if _cam_pitch > 0.0:
		EnvCamStudy.apply(cam, _content.arena, size, top, bottom, _cam_pitch, _cam_persp)
	_base_size = cam.size
	_base_xf = cam.transform
	cam.size = _base_size
	cam.transform = _base_xf
	if _mode == "close":
		cam.size = _base_size / _zoom
		_follow_close()
	if CAM_AZIMUTH.has(_mode):
		_extra_cam.make_current()
	else:
		cam.make_current()


## The top-down close-up: the game camera shifted sideways and up so the focused actor is in the middle.
func _follow_close() -> void:
	var pose: LookActorsFocus.Pose = _focus.resolve(_view.actor_layer, _puppet.world)
	var cam: Camera3D = _view.camera_rig.camera
	var local: Vector3 = _base_xf.affine_inverse() * pose.at
	cam.transform = Transform3D(_base_xf.basis, _base_xf.origin + _base_xf.basis * Vector3(local.x, local.y, 0.0))


## The low solo cameras orbit the focused actor (the Warden by default) at a fixed azimuth from its facing, at a distance that
## scales with its height, and look at its middle.
func _update_camera(_warden: WardenView) -> void:
	if _mode == "close":
		_follow_close()
		return
	if not CAM_AZIMUTH.has(_mode):
		return
	var pose: LookActorsFocus.Pose = _focus.resolve(_view.actor_layer, _puppet.world)
	var yaw: float = pose.yaw + deg_to_rad(CAM_AZIMUTH[_mode])
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var elev: float = deg_to_rad(CAM_ELEVATION_DEG)
	var dist: float = CAM_DISTANCE * maxf(pose.height, 0.9) / 1.9
	var from: Vector3 = pose.at + forward * (dist * cos(elev)) + Vector3(0.0, dist * sin(elev), 0.0)
	_extra_cam.look_at_from_position(from, pose.at, Vector3.UP)


func _hide_enemies() -> void:
	for node_name: String in SOLO_HIDDEN:
		var hidden_node: Node3D = _view.arena_view.get_node_or_null(node_name) as Node3D
		if hidden_node != null:
			hidden_node.visible = false
	var layer: ActorLayer = _view.actor_layer
	for c: Node in layer.get_children():
		var root: Node3D = c as Node3D
		if root != null and root.get_child_count() == 1 and root.get_child(0) is MeshInstance3D and String(root.name).contains("_"):
			root.visible = false
	var decals: ActorDecals = layer.decals()
	decals.bar_bg_node.visible = false
	decals.bar_fill_node.visible = false
	# the blob shadows of the enemies come first in the instance list, then the Warden's, then the turrets'
	var mm: MultiMesh = decals.shadow_node.multimesh
	var deployed: int = 0
	for t: TurretView in layer.turrets:
		if t.is_deployed():
			deployed += 1
	var warden_index: int = mm.visible_instance_count - 1 - deployed
	var gone: Transform3D = Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -50.0, 0.0))
	for i: int in clampi(warden_index, 0, mm.instance_count):
		mm.set_instance_transform(i, gone)
