extends Control
## CombatHud + FakeRunApi cycling through states (ARCH 11).

const STEP_SECONDS: float = 1.5

var _api: FakeRunApi = FakeRunApi.new()
var _hud: CombatHud
var _t: float = 0.0
var _step: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.build(Content.db.tokens, false)
	var packed: PackedScene = load("res://src/ui/combat/combat_hud.tscn") as PackedScene
	_hud = packed.instantiate() as CombatHud
	add_child(_hud)
	_hud.setup(_api, Content.db, null)
	_apply_step()


func _process(delta: float) -> void:
	_t += delta
	if _t >= STEP_SECONDS:
		_t = 0.0
		_step += 1
		_apply_step()


func _apply_step() -> void:
	_api.set_scrap(_step * 125)
	_api.set_core(maxf(0.0, 1000.0 - float(_step) * 70.0))
	_hud.refresh()
