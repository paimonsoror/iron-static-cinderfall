class_name ResultsScreen
extends Control
## Wave 0 stub: a title and one button per signal. TODO(W2-B/W1-G) replaces the body; the signals and
## the setup signature are the frozen contract (ARCH 9).

signal retry_pressed
signal menu_pressed

var _built: bool = false
var _info_label: Label


func _ready() -> void:
	_ensure_built()


@warning_ignore("unused_parameter")
func setup(summary: RunSummary, content: ContentSet, profile: Profile, reward_granted: bool) -> void:
	_ensure_built()
	_info_label.text = "data +%d" % (summary.data_reward if reward_granted else 0)


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var col: VBoxContainer = UiKit.stub_layout(self, "results.title")
	_info_label = Label.new()
	col.add_child(_info_label)
	var b_retry_pressed: Button = UiKit.button("results.retry")
	b_retry_pressed.pressed.connect(func() -> void: retry_pressed.emit())
	col.add_child(b_retry_pressed)
	var b_menu_pressed: Button = UiKit.button("results.menu")
	b_menu_pressed.pressed.connect(func() -> void: menu_pressed.emit())
	col.add_child(b_menu_pressed)
