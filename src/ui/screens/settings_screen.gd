class_name SettingsScreen
extends Control
## Settings (GDD 10.2): Sound, Music, Haptics, Reduced Flash, High Contrast, Swap assist as ON/OFF rows, Quality (LOW/MID/HIGH)
## and FPS cap (30/60) as choices. Every change is written through Save.set_setting and put to work at once
## (UiSettingsApply; High Contrast re-skins this screen on the settings_changed signal). `closed` and setup() are
## the frozen contract (ARCH 9); setup() reads the current values from Save.

signal closed

## Setting key and its row text, in display order.
const TOGGLES: Array[Dictionary] = [
	{"key": &"sound_on", "title": "settings.sound", "hint": "settings.sound.hint"},
	{"key": &"music_on", "title": "settings.music", "hint": "settings.music.hint"},
	{"key": &"haptics_on", "title": "settings.haptics", "hint": "settings.haptics.hint"},
	{"key": &"reduced_flash", "title": "settings.reduced_flash", "hint": "settings.reduced_flash.hint"},
	{"key": &"high_contrast", "title": "settings.high_contrast", "hint": "settings.high_contrast.hint"},
	{"key": &"swap_assist", "title": "settings.swap_assist", "hint": "settings.swap_assist.hint"},
]
const QUALITY_KEYS: PackedStringArray = ["settings.quality.low", "settings.quality.mid", "settings.quality.high"]
const QUALITY_VALUES: Array[int] = [0, 1, 2]  ## VisualQuality.Tier LOW, MID, HIGH
const FPS_KEYS: PackedStringArray = ["settings.fps.30", "settings.fps.60"]
const FPS_VALUES: Array[int] = [30, 60]

var header_plate: UiHeaderPlate
var toggle_rows: Dictionary[StringName, UiToggleRow] = {}
var quality_row: UiSegmentedRow
var fps_row: UiSegmentedRow
var close_button: Button
var _built: bool = false


func _ready() -> void:
	_ensure_built()


## Shows the stored values (no setting is written).
func setup() -> void:
	_ensure_built()
	for key: StringName in toggle_rows:
		toggle_rows[key].set_on(_stored_bool(key))
	quality_row.set_value(_stored_int(&"quality", 2))
	fps_row.set_value(_stored_int(&"fps_cap", 60))


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var frame: UiScreenFrame = UiScreenFrame.new(UiBackdrop.Mode.PLAIN)
	add_child(frame)
	header_plate = UiHeaderPlate.new(Strings.t("settings.title"))
	frame.header.add_child(header_plate)
	for spec: Dictionary in TOGGLES:
		var key: StringName = spec["key"]
		var title_key: String = spec["title"]
		var hint_key: String = spec["hint"]
		var row: UiToggleRow = UiToggleRow.new(title_key, hint_key, _stored_bool(key))
		row.changed.connect(_on_toggle.bind(key))
		toggle_rows[key] = row
		frame.content.add_child(row)
	quality_row = UiSegmentedRow.new(
		"settings.quality", "settings.quality.hint", QUALITY_KEYS, QUALITY_VALUES, _stored_int(&"quality", 2)
	)
	quality_row.selected.connect(_on_choice.bind(&"quality"))
	frame.content.add_child(quality_row)
	fps_row = UiSegmentedRow.new("settings.fps", "settings.fps.hint", FPS_KEYS, FPS_VALUES, _stored_int(&"fps_cap", 60))
	fps_row.selected.connect(_on_choice.bind(&"fps_cap"))
	frame.content.add_child(fps_row)
	close_button = UiKit.button_primary("settings.close")
	close_button.pressed.connect(func() -> void: closed.emit())
	frame.footer.add_child(close_button)


func _on_toggle(on: bool, key: StringName) -> void:
	Save.set_setting(key, on)
	UiSettingsApply.apply(key)


func _on_choice(value: int, key: StringName) -> void:
	Save.set_setting(key, value)
	UiSettingsApply.apply(key)


func _stored_bool(key: StringName) -> bool:
	var v: Variant = Save.get_setting(key)
	if typeof(v) != TYPE_BOOL:
		return false
	var on: bool = v
	return on


func _stored_int(key: StringName, fallback: int) -> int:
	var v: Variant = Save.get_setting(key)
	if typeof(v) != TYPE_INT:
		return fallback
	var n: int = v
	return n
