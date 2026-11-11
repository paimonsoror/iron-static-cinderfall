class_name MainMenuScreen
extends Control
## Wave 0 stub: a title and one button per signal. TODO(W2-B/W1-G) replaces the body; the signals and
## the setup signature are the frozen contract (ARCH 9).

signal start_pressed
signal settings_pressed
signal quit_pressed

var _built: bool = false
var _data_label: Label


func _ready() -> void:
	_ensure_built()


@warning_ignore("unused_parameter")
func setup(profile: Profile) -> void:
	_ensure_built()
	_data_label.text = "%d" % profile.data


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var col: VBoxContainer = UiKit.stub_layout(self, "menu.title")
	_data_label = Label.new()
	col.add_child(_data_label)
	var b_start_pressed: Button = UiKit.button("menu.start")
	b_start_pressed.pressed.connect(func() -> void: start_pressed.emit())
	col.add_child(b_start_pressed)
	var b_settings_pressed: Button = UiKit.button("menu.settings")
	b_settings_pressed.pressed.connect(func() -> void: settings_pressed.emit())
	col.add_child(b_settings_pressed)
	var b_quit_pressed: Button = UiKit.button("menu.quit")
	b_quit_pressed.pressed.connect(func() -> void: quit_pressed.emit())
	col.add_child(b_quit_pressed)
