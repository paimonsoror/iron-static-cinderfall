class_name HudEdgeArrow
extends Control
## One edge arrow (VARIETY_SPEC 11.4): two chevrons that point toward where an event arrives, and the event's one word beside
## them ("RECOUNT", "BREACH"). The word is the state, the chevrons are the shape and the red is only a third cue (never colour
## alone). Information only: it takes no taps.

const W: float = 250.0
const H: float = 76.0
const CHEVRON_X: float = 42.0

var angle: float = 0.0  ## radians; the direction the chevrons point (0 = right, screen y grows down)
var word_label: Label
var event_id: StringName = &""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	word_label = HudStyle.make_label("", HudStyle.FONT_SMALL + 2, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(word_label)
	HudStyle.outline(word_label, 6)
	word_label.position = Vector2(CHEVRON_X + 44.0, 16.0)
	word_label.size = Vector2(W - CHEVRON_X - 44.0, H - 16.0)
	add_child(word_label)


func show_arrow(id: StringName, word: String, direction: float) -> void:
	event_id = id
	word_label.text = word
	angle = direction
	visible = true
	queue_redraw()


func _draw() -> void:
	var red: Color = HudStyle.color(&"chorus_red").lightened(0.15)
	var dark: Color = HudStyle.alpha(HudStyle.color(&"obsidian"), 0.9)
	draw_set_transform(Vector2(CHEVRON_X, H * 0.5), angle, Vector2.ONE)
	for pass_index: int in 2:  # the dark outline first, then the red stroke over it
		var width: float = 16.0 if pass_index == 0 else 8.0
		var tone: Color = dark if pass_index == 0 else red
		for k: int in 2:
			var x: float = -14.0 + 20.0 * float(k)
			draw_polyline(PackedVector2Array([Vector2(x, -22.0), Vector2(x + 18.0, 0.0), Vector2(x, 22.0)]), tone, width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
