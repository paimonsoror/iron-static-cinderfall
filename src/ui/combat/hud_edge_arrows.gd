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
var avoid: Rect2 = Rect2()  ## a rectangle in this control's space (the wave banner) the arrows slide clear of; empty = none
var _events: Array[Dictionary] = []  ## the last refresh, kept so a new size can put the arrows back at the edge
var _to_screen: Callable = Callable()


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
	_events = events
	_to_screen = to_screen
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


## Puts the arrows of the last refresh back at the edge of the (resized or moved) zone; `origin` is where this control's top-left
## corner is now. Without it an arrow placed before the first layout sat outside the screen until the next 10 Hz refresh.
func replace(origin: Vector2) -> void:
	if _to_screen.is_valid():
		refresh(_events, _to_screen, origin)


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
	_clear_of_banner(arrow)
	arrow.show_arrow(id, Strings.t(WORDS[id]), direction.angle())


## An arrow that would sit on the banner slides along the edge to just below it (or above it when there is no room below): the
## chevrons still point where the event arrives, only the place on the ray moves.
func _clear_of_banner(arrow: HudEdgeArrow) -> void:
	if avoid.size.x <= 0.0:
		return
	var box: Rect2 = Rect2(arrow.position, Vector2(HudEdgeArrow.W, HudEdgeArrow.H))
	if not box.intersects(avoid):
		return
	var below: float = avoid.end.y + 8.0
	if below + HudEdgeArrow.H <= size.y - INSET:
		arrow.position.y = below
	else:
		arrow.position.y = maxf(avoid.position.y - HudEdgeArrow.H - 8.0, 0.0)
