class_name BriefingScreen
extends Control
## Wave 0 stub: a title and one button per signal. TODO(W2-B/W1-G) replaces the body; the signals and
## the setup signature are the frozen contract (ARCH 9).

signal deploy_pressed
signal back_pressed

var _built: bool = false
var _info_label: Label


func _ready() -> void:
	_ensure_built()


@warning_ignore("unused_parameter")
func setup(content: ContentSet) -> void:
	_ensure_built()
	_info_label.text = Strings.t(content.mission.name_key)


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var col: VBoxContainer = UiKit.stub_layout(self, "briefing.title")
	_info_label = Label.new()
	col.add_child(_info_label)
	var b_deploy_pressed: Button = UiKit.button("briefing.deploy")
	b_deploy_pressed.pressed.connect(func() -> void: deploy_pressed.emit())
	col.add_child(b_deploy_pressed)
	var b_back_pressed: Button = UiKit.button("briefing.back")
	b_back_pressed.pressed.connect(func() -> void: back_pressed.emit())
	col.add_child(b_back_pressed)
