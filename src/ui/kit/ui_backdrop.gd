class_name UiBackdrop
extends Control
## The drawn background of a screen (no textures): an obsidian gradient with a faint ground grid. HERO mode adds a
## low view of the freight yard: Relay Core B-4 (amber), the Warden on its cyan pad, gantry silhouettes and rain
## (GDD 10.2: the one place a hero backdrop is allowed). VICTORY and DEFEAT add only the core's glow (amber, or a
## dim red when it is lost). Everything is drawn once and redrawn on resize.

enum Mode { PLAIN, HERO, VICTORY, DEFEAT }

const RAIN_STREAKS: int = 90
const GLOW_RINGS: int = 28

var mode: int = Mode.PLAIN:
	set(value):
		mode = value
		queue_redraw()


func _init(start_mode: int = Mode.PLAIN) -> void:
	mode = start_mode
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	if s.x < 8.0 or s.y < 8.0:
		return
	var obsidian: Color = UiTheme.color(&"obsidian")
	var horizon: float = s.y * (0.5 if mode == Mode.HERO else 0.62)
	_gradient(Rect2(0.0, 0.0, s.x, horizon), obsidian.darkened(0.25), _haze_color(obsidian))
	_gradient(Rect2(0.0, horizon, s.x, s.y - horizon), obsidian.lerp(Color.BLACK, 0.15), obsidian.darkened(0.45))
	_ground_grid(s, horizon)
	if mode == Mode.HERO:
		_gantry(s, horizon, 0.04, 0.26)
		_gantry(s, horizon, 0.80, 0.98)
		var core_at: Vector2 = Vector2(s.x * 0.64, horizon + s.y * 0.04)
		_glow(core_at + Vector2(0.0, -s.x * 0.05), s.x * 0.34, UiTheme.color(&"core_amber"), 0.42)
		_core(core_at, s.x)
		_warden(Vector2(s.x * 0.2, horizon + s.y * 0.075), s.y)
		_rain(s)
	elif mode == Mode.VICTORY:
		_glow(Vector2(s.x * 0.5, horizon), s.x * 0.3, UiTheme.color(&"core_amber"), 0.3)
	elif mode == Mode.DEFEAT:
		_glow(Vector2(s.x * 0.5, horizon), s.x * 0.22, UiTheme.color(&"chorus_red"), 0.16)
	_gradient(Rect2(0.0, 0.0, s.x, s.y * 0.16), Color(0.0, 0.0, 0.0, 0.5), Color(0.0, 0.0, 0.0, 0.0))
	_gradient(Rect2(0.0, s.y * 0.8, s.x, s.y * 0.2), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.6))


## Horizon haze: amber on the hero scene and on a win, red on a loss, a cool blue-grey otherwise.
func _haze_color(obsidian: Color) -> Color:
	var tint: Color = UiTheme.color(&"warden_cyan")
	var amount: float = 0.07
	if mode == Mode.HERO or mode == Mode.VICTORY:
		tint = UiTheme.color(&"core_amber")
		amount = 0.2 if mode == Mode.HERO else 0.12
	elif mode == Mode.DEFEAT:
		tint = UiTheme.color(&"chorus_red")
		amount = 0.14
	return obsidian.lerp(tint, amount)


func _gradient(r: Rect2, top: Color, bottom: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y),
	])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


func _ground_grid(s: Vector2, horizon: float) -> void:
	var line: Color = UiTheme.alpha(UiTheme.color(&"warden_cyan"), 0.1)
	var vanish: Vector2 = Vector2(s.x * 0.5, horizon - s.y * 0.2)
	var depth: float = s.y - horizon
	var t: float = (horizon - vanish.y) / (s.y - vanish.y)
	for i: int in range(-6, 17):
		var x: float = s.x * float(i) / 10.0
		draw_line(vanish.lerp(Vector2(x, s.y), t), Vector2(x, s.y), line, 2.0)
	for k: int in range(1, 11):
		var f: float = pow(float(k) / 10.0, 2.2)
		var y: float = horizon + depth * f
		draw_line(Vector2(0.0, y), Vector2(s.x, y), UiTheme.alpha(line, 0.1 + 0.9 * f), 2.0)
	draw_line(Vector2(0.0, horizon), Vector2(s.x, horizon), UiTheme.alpha(UiTheme.color(&"gunmetal"), 0.4), 2.0)


## A gantry: two legs, cross bracing and a top beam, in a dark steel tone, between x fractions `a` and `b`.
func _gantry(s: Vector2, horizon: float, a: float, b: float) -> void:
	var steel: Color = UiTheme.color(&"gunmetal").lerp(UiTheme.color(&"obsidian"), 0.65)
	var x0: float = s.x * a
	var x1: float = s.x * b
	var top: float = horizon - s.y * 0.3
	draw_line(Vector2(x0, horizon), Vector2(x0 + (x1 - x0) * 0.08, top), steel, 12.0)
	draw_line(Vector2(x1, horizon), Vector2(x1 - (x1 - x0) * 0.08, top), steel, 12.0)
	draw_line(Vector2(x0, top), Vector2(x1, top), steel, 14.0)
	var rungs: int = 6
	for i: int in rungs:
		var y0: float = lerpf(horizon, top, float(i) / float(rungs))
		var y1: float = lerpf(horizon, top, float(i + 1) / float(rungs))
		draw_line(Vector2(x0, y0), Vector2(x1, y1), steel, 4.0)
		draw_line(Vector2(x1, y0), Vector2(x0, y1), steel, 4.0)


## A soft halo: many faint discs of shrinking radius (no hard rings). `strength` is the alpha at the centre.
func _glow(at: Vector2, radius: float, tint: Color, strength: float) -> void:
	for i: int in GLOW_RINGS:
		var f: float = float(i) / float(GLOW_RINGS - 1)
		var a: float = strength * (0.5 / float(GLOW_RINGS)) * (1.0 + 2.0 * f)
		draw_circle(at, radius * (1.0 - 0.85 * f), UiTheme.alpha(tint, a))


## Relay Core B-4: a ring on the ground and a caged glowing column.
func _core(at: Vector2, width: float) -> void:
	var amber: Color = UiTheme.color(&"core_amber")
	var steel: Color = UiTheme.color(&"gunmetal").lerp(UiTheme.color(&"obsidian"), 0.4)
	var h: float = width * 0.30
	var w: float = width * 0.085
	draw_colored_polygon(_ellipse(at, w * 1.7, w * 0.5), UiTheme.alpha(amber, 0.28))
	draw_polyline(_ellipse_line(at, w * 1.7, w * 0.5), UiTheme.alpha(amber, 0.7), 2.0)
	draw_rect(Rect2(at.x - w * 0.5, at.y - h, w, h), amber.lerp(Color.WHITE, 0.12))
	draw_rect(Rect2(at.x - w * 0.18, at.y - h, w * 0.36, h), amber.lerp(Color.WHITE, 0.55))
	for i: int in 5:
		var cx: float = at.x - w * 0.62 + w * 1.24 * float(i) / 4.0
		draw_line(Vector2(cx, at.y), Vector2(cx, at.y - h * 1.04), steel, 6.0)
	draw_line(Vector2(at.x - w * 0.7, at.y - h * 1.04), Vector2(at.x + w * 0.7, at.y - h * 1.04), steel, 10.0)
	draw_line(Vector2(at.x - w * 0.7, at.y), Vector2(at.x + w * 0.7, at.y), steel, 10.0)


## The Warden facing the core: bone-ceramic plates over a gunmetal frame, a cyan slit visor and shoulder light, a
## sidearm raised, planted wide on its cyan ring. Authored in units of about 1.2 px at 2400 px height.
func _warden(at: Vector2, scale_y: float) -> void:
	var u: float = scale_y * 0.0005
	var cyan: Color = UiTheme.color(&"warden_cyan")
	var obsidian: Color = UiTheme.color(&"obsidian")
	var plate: Color = UiTheme.color(&"bone_ceramic").lerp(obsidian, 0.3)
	var frame: Color = UiTheme.color(&"gunmetal").lerp(obsidian, 0.45)
	var edge: Color = obsidian.darkened(0.3)
	draw_colored_polygon(_ellipse(at, 170.0 * u, 46.0 * u), UiTheme.alpha(cyan, 0.16))
	draw_polyline(_ellipse_line(at, 170.0 * u, 46.0 * u), UiTheme.alpha(cyan, 0.8), 3.0)
	_part(at, u, [Vector2(-62, -128), Vector2(-20, -128), Vector2(-26, -4), Vector2(-72, -4)], frame, edge)
	_part(at, u, [Vector2(20, -128), Vector2(62, -128), Vector2(74, -4), Vector2(28, -4)], frame, edge)
	_part(at, u, [Vector2(-60, -150), Vector2(60, -150), Vector2(56, -120), Vector2(-56, -120)], frame, edge)
	_part(at, u, [Vector2(-72, -268), Vector2(72, -268), Vector2(54, -150), Vector2(-54, -150)], plate, edge)
	_part(at, u, [Vector2(-104, -278), Vector2(-62, -278), Vector2(-58, -226), Vector2(-100, -232)], plate, edge)
	_part(at, u, [Vector2(62, -278), Vector2(104, -278), Vector2(100, -232), Vector2(58, -226)], plate, edge)
	_part(at, u, [Vector2(-30, -322), Vector2(30, -322), Vector2(34, -274), Vector2(-34, -274)], frame, edge)
	draw_rect(Rect2(at.x + 2.0 * u, at.y - 304.0 * u, 26.0 * u, 7.0 * u), cyan)
	draw_rect(Rect2(at.x - 100.0 * u, at.y - 262.0 * u, 22.0 * u, 14.0 * u), cyan)
	draw_line(at + Vector2(0.0, -236.0) * u, at + Vector2(0.0, -160.0) * u, edge, 2.0)
	draw_line(at + Vector2(86.0, -250.0) * u, at + Vector2(146.0, -224.0) * u, frame, 18.0 * u)
	_part(at, u, [Vector2(140, -240), Vector2(206, -240), Vector2(206, -222), Vector2(150, -222)], frame, edge)


func _part(at: Vector2, u: float, points: Array[Vector2], fill: Color, outline: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		pts.append(at + p * u)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, outline, 2.0, true)


func _rain(s: Vector2) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4091
	var col: Color = UiTheme.alpha(UiTheme.color(&"bone_ceramic"), 0.1)
	for i: int in RAIN_STREAKS:
		var x: float = rng.randf_range(0.0, s.x)
		var y: float = rng.randf_range(0.0, s.y)
		var streak: float = rng.randf_range(30.0, 90.0)
		draw_line(Vector2(x, y), Vector2(x - streak * 0.18, y + streak), col, 2.0)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = _ellipse_line(c, rx, ry)
	pts.remove_at(pts.size() - 1)
	return pts


func _ellipse_line(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 40
	for i: int in n + 1:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
