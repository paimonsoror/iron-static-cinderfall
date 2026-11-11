class_name BootScreen
extends Control
## Wave 0 stub: a title and one button per signal. TODO(W2-B/W1-G) replaces the body; the signals and
## the setup signature are the frozen contract (ARCH 9).

signal finished

var _built: bool = false
var _version_label: Label


func _ready() -> void:
	_ensure_built()


@warning_ignore("unused_parameter")
func setup(version: String) -> void:
	_ensure_built()
	_version_label.text = version


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var col: VBoxContainer = UiKit.stub_layout(self, "boot.title")
	_version_label = Label.new()
	col.add_child(_version_label)
	var b_finished: Button = UiKit.button("boot.continue")
	b_finished.pressed.connect(func() -> void: finished.emit())
	col.add_child(b_finished)
