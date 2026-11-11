class_name PauseOverlay
extends Control
## Wave 0 stub: a title and one button per signal. TODO(W2-B/W1-G) replaces the body; the signals and
## the setup signature are the frozen contract (ARCH 9).

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal quit_pressed

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
	var col: VBoxContainer = UiKit.stub_layout(self, "pause.title")
	var b_resume_pressed: Button = UiKit.button("pause.resume")
	b_resume_pressed.pressed.connect(func() -> void: resume_pressed.emit())
	col.add_child(b_resume_pressed)
	var b_restart_pressed: Button = UiKit.button("pause.restart")
	b_restart_pressed.pressed.connect(func() -> void: restart_pressed.emit())
	col.add_child(b_restart_pressed)
	var b_settings_pressed: Button = UiKit.button("pause.settings")
	b_settings_pressed.pressed.connect(func() -> void: settings_pressed.emit())
	col.add_child(b_settings_pressed)
	var b_quit_pressed: Button = UiKit.button("pause.quit")
	b_quit_pressed.pressed.connect(func() -> void: quit_pressed.emit())
	col.add_child(b_quit_pressed)
