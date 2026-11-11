extends Node
## BattleView + SimPuppet (ARCH 11). The puppet runs a scenario on the real sim systems; the view renders it exactly
## as it will render a run. Works inside the game, in the main window, and inside the capture SubViewport.
##   --scenario=hold10|hold28|hold50|boss   crowd (default hold50)
##   --quality=0|1|2                        LOW, MID, HIGH (default MID)
##   --high-contrast  --reduced-flash       accessibility looks
##   --debug-overlay[=all|flow,slots,stuck,spawns]   debug layers   --debug-perf   PerfHud and the [PERF] log line
##   --seed=<n>   --look=current|stylised|stylised_plus   the Warden look (W3-C look-dev; see look_dev_sandbox.tscn for the rest)
## In a capture the puppet steps a fixed 1/60 s per frame, so `--capture-frames=N` always shows second N/60 of the
## scenario (turrets 0.5 s and 1 s, SMG 1.5 s, stuck 1.2 s, shield 2 s, overdrive 3 s, EMP 8 s).
## Desktop keys: F1 flow  F2 slots  F3 stuck  F4 spawns  F5 quality  F6 high contrast  F7 perf overlay.

var _view: BattleView
var _puppet: SimPuppet
var _content: ContentSet
var _overlay: BattleDebugOverlay
var _perf: PerfHud
var _perf_layer: CanvasLayer
var _fixed_step: bool = false
var _tier: int = VisualQuality.Tier.MID
var _high_contrast: bool = false


func _ready() -> void:
	_content = Content.db
	var args: DebugArgs = DebugArgs.from_os()
	_fixed_step = args.wants_capture()
	var packed: PackedScene = load("res://src/view/battle_view.tscn") as PackedScene
	_view = packed.instantiate() as BattleView
	add_child(_view)
	_view.setup(_content)
	_tier = args.quality if args.quality >= 0 else VisualQuality.Tier.MID
	_high_contrast = args.high_contrast
	_view.set_quality(_tier)
	_view.set_high_contrast(_high_contrast)
	_view.set_reduced_flash(args.reduced_flash)
	if args.look >= 0:
		_view.actor_layer.set_look(args.look)
		_view.arena_view.set_look(args.look)
	_puppet = SimPuppet.new()
	add_child(_puppet)
	_puppet.setup(_content, args.scenario if args.scenario != "" else "hold50", args.run_seed if args.has_seed else 1)
	_view.bind(_puppet.world)
	_overlay = BattleDebugOverlay.new()
	_overlay.setup(_content.arena)
	_view.add_child(_overlay)
	_overlay.bind(_puppet.world)
	_overlay.apply_spec(args.debug_overlay)
	if args.debug_perf:
		_add_perf_hud()
	get_viewport().size_changed.connect(_refit)
	_refit()


func _process(delta: float) -> void:
	var dt: float = SimPuppet.TICK_DT if _fixed_step else delta
	var alpha: float = _puppet.advance(dt)
	if _fixed_step:
		alpha = 1.0
	_view.render(alpha, dt)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			_overlay.toggle(BattleDebugOverlay.Layer.FLOW)
		KEY_F2:
			_overlay.toggle(BattleDebugOverlay.Layer.SLOTS)
		KEY_F3:
			_overlay.toggle(BattleDebugOverlay.Layer.STUCK)
		KEY_F4:
			_overlay.toggle(BattleDebugOverlay.Layer.SPAWNS)
		KEY_F5:
			_tier = (_tier + 1) % 3
			_view.set_quality(_tier)
			Log.info("sandbox", "quality=%s" % VisualQuality.name_of(_tier))
		KEY_F6:
			_high_contrast = not _high_contrast
			_view.set_high_contrast(_high_contrast)
		KEY_F7:
			if _perf == null:
				_add_perf_hud()
			else:
				_perf_layer.visible = not _perf_layer.visible


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


func _refit() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var top: float = HudLayout.top_band_px(size, Vector4.ZERO, _content.tokens)
	var bottom: float = HudLayout.bottom_band_px(size, Vector4.ZERO, _content.tokens)
	_view.fit_camera(size, top, bottom)
