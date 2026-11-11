class_name SettingsScreen
extends Control
## Wave 0 stub: a title and one button per signal. TODO(W2-B/W1-G) replaces the body; the signals and
## the setup signature are the frozen contract (ARCH 9).

signal closed

var _built: bool = false


func _ready() -> void:
	_ensure_built()


@warning_ignore("unused_parameter")
func setup() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var col: VBoxContainer = UiKit.stub_layout(self, "settings.title")
	var b_closed: Button = UiKit.button("settings.close")
	b_closed.pressed.connect(func() -> void: closed.emit())
	col.add_child(b_closed)
