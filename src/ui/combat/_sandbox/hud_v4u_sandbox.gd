class_name HudV4uSandbox
extends Control
## Capture sandbox of the V4-U combat HUD parts (not part of the game): the combat HUD over a flat stand-in for the battlefield, on
## a FakeRunApi. The scene file name picks the state: hud_v4u_ticker, hud_v4u_arrows, hud_v4u_boss, hud_v4u_bar or hud_v4u_pause.
## Example: capture.ps1 -Scene res://src/ui/combat/_sandbox/hud_v4u_ticker_sandbox.tscn -Out build/shots/v4u_ticker.png -Size 1080x2400

var _api: FakeRunApi = FakeRunApi.new()
var _hud: CombatHud


func _ready() -> void:
	var which: String = scene_file_path.get_file().get_basename().trim_suffix("_sandbox").trim_prefix("hud_v4u_")
	UiKit.fill(self)
	theme = UiTheme.build(Content.db.tokens, false)
	var field: ColorRect = ColorRect.new()
	field.color = Color(0.13, 0.18, 0.22)
	UiKit.fill(field)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	var packed: PackedScene = load("res://src/ui/combat/combat_hud.tscn") as PackedScene
	_hud = packed.instantiate() as CombatHud
	add_child(_hud)
	var ok: bool = FakeRunPresets.apply(_api, Content.db, "combat2")
	assert(ok)
	_hud.setup(_api, Content.db, null)
	match which:
		"ticker":
			_ticker()
		"arrows":
			_arrows()
		"boss":
			_boss()
		"pause":
			_pause()
	_hud.refresh()


func _event(id: StringName, phase: int, harmful: bool, ticks_left: int, ticks_total: int, x: float = 0.0, z: float = 0.0) -> Dictionary:
	return {"id": id, "phase": phase, "ticks_left": ticks_left, "ticks_total": ticks_total, "harmful": harmful, "x": x, "z": z}


## Three lines by priority: a harmful warning, a crate in the clear, a running harmful event; a helpful one waits out.
func _ticker() -> void:
	_api.fake_active_events = [
		_event(&"accord_window", 1, false, 400, 900),
		_event(&"floor_breach", 1, true, 200, 600, 10.0, -12.0),
		_event(&"static_front", 0, true, 300, 360),
	]
	_api.fake_crate_status = {"contested": false, "ticks_left": 240, "ticks_total": 600, "life_left": -1, "x": 4.0, "z": 2.0}


## A RECOUNT from the left and a floor breach to the upper right, with their ticker lines.
func _arrows() -> void:
	var arena: ArenaDef = Content.db.arena
	_api.fake_active_events = [
		_event(&"recount", 0, true, 240, 360, arena.min_x, (arena.min_z + arena.max_z) * 0.5),
		_event(&"floor_breach", 0, true, 180, 360, arena.max_x - 4.0, arena.min_z + 2.0),
	]


## A boss bar with three phase pips, the second phase reached.
func _boss() -> void:
	_api.fake_wave = 5
	_api.fake_boss_hp = 1800.0
	_api.fake_boss_max_hp = 2800.0
	_api.fake_boss_phase = 1
	_api.fake_boss_phase_count = 3
	Events.boss_spawned.emit(1, &"siege_hulk")


## The pause overlay of a generated run over the HUD: the seed line and the BUILD button.
func _pause() -> void:
	var packed: PackedScene = load("res://src/ui/combat/pause_overlay.tscn") as PackedScene
	var overlay: PauseOverlay = packed.instantiate() as PauseOverlay
	add_child(overlay)
	overlay.setup()
