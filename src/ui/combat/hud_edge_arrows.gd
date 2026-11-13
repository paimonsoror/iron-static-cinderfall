class_name HudEdgeArrows
extends Control
## The edge arrows of the combat HUD (VARIETY_SPEC 11.4, GDD 10.1): while a RECOUNT, a floor breach or a runaway freight is
## warning or running, a chevron arrow sits at the edge of the battlefield, on the ray from the middle of the field to where the
## event arrives, and points there with its word. Positions come from the RunApi's `active_events()` (world x, z) through a
## `to_screen` Callable (`BattleView.world_to_screen` in the game; a linear map of the arena without a view). The ticker keeps the
## text and the countdown; these only say where. Fills the battlefield zone and ignores the mouse.

const WORDS: Dictionary[StringName, String] = {
	&"recount": "hud.arrow.recount",
	&"floor_breach": "hud.arrow.breach",
	&"runaway_freight": "hud.arrow.freight",
}
const INSET: float = 18.0
const MAX_ARROWS: int = 3

var arrows: Array[HudEdgeArrow] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in MAX_ARROWS:
		var arrow: HudEdgeArrow = HudEdgeArrow.new()
		arrow.visible = false
		add_child(arrow)
		arrows.append(arrow)


## Shows an arrow for every warning or running event that has one (at most MAX_ARROWS), hides the rest. `to_screen` maps a
## world point (x, z) to a position in the HUD's space and `origin` is where this control's top-left corner is in that space.
func refresh(events: Array[Dictionary], to_screen: Callable, origin: Vector2) -> void:
	var shown: int = 0
	for e: Dictionary in events:
		var id: StringName = e.get("id", &"")
		if shown >= MAX_ARROWS or not WORDS.has(id):
			continue
		var wx: float = e.get("x", 0.0)
		var wz: float = e.get("z", 0.0)
		var target: Vector2 = to_screen.call(wx, wz)
		var spot: Vector2 = target - origin
		_place(arrows[shown], id, spot)
		shown += 1
	for i: int in range(shown, MAX_ARROWS):
		arrows[i].visible = false


## The count of arrows on screen.
func visible_count() -> int:
	var n: int = 0
	for arrow: HudEdgeArrow in arrows:
		if arrow.visible:
			n += 1
	return n


## Puts `arrow` on the inset rectangle of the zone where the ray from the zone's middle to `spot` leaves it.
func _place(arrow: HudEdgeArrow, id: StringName, spot: Vector2) -> void:
	var centre: Vector2 = size * 0.5
	var direction: Vector2 = spot - centre
	if direction.length() < 1.0:
		direction = Vector2.UP
	var half: Vector2 = Vector2(maxf(centre.x - INSET - HudEdgeArrow.W * 0.5, 1.0), maxf(centre.y - INSET - HudEdgeArrow.H * 0.5, 1.0))
	var k: float = minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	var anchor: Vector2 = centre + direction * k
	arrow.position = anchor - Vector2(HudEdgeArrow.W, HudEdgeArrow.H) * 0.5
	arrow.show_arrow(id, Strings.t(WORDS[id]), direction.angle())
