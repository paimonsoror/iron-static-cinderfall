class_name UiEnemyGlyph
extends Control
## A flat, drawn silhouette of one CHORUS machine for threat lists (GDD 6): bone-ceramic plates over a dark gunmetal
## frame, a dark blob shadow and ONE red optic (never a pair of eyes, never a skull). Authored in a 100 x 100 box
## and scaled to the control; no textures.

const BOX: float = 100.0

var enemy_id: StringName = &"skitter"


func _init(id: StringName = &"skitter", px: float = 140.0) -> void:
	enemy_id = id
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var k: float = minf(size.x, size.y) / BOX
	if k <= 0.0:
		return
	draw_set_transform(Vector2((size.x - BOX * k) * 0.5, (size.y - BOX * k) * 0.5), 0.0, Vector2(k, k))
	var plate: Color = UiTheme.color(&"bone_ceramic").lerp(UiTheme.color(&"obsidian"), 0.12)
	var frame: Color = UiTheme.color(&"gunmetal").lerp(UiTheme.color(&"obsidian"), 0.25)
	var edge: Color = UiTheme.color(&"obsidian")
	var optic: Color = UiTheme.color(&"chorus_red")
	if UiTheme.high_contrast_on():
		optic = optic.lerp(Color.WHITE, 0.35)
		frame = frame.lightened(0.15)
	draw_colored_polygon(_oval(Vector2(50.0, 90.0), 38.0, 5.0), UiTheme.alpha(Color.BLACK, 0.45))
	match enemy_id:
		&"hollow_warden":
			_hollow_warden(plate, frame, edge, optic)
		&"rusher":
			_rusher(plate, frame, edge, optic)
		&"siege_hulk":
			_siege_hulk(plate, frame, edge, optic)
		_:
			_skitter(plate, frame, edge, optic)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Low four-legged crawler, long forelimbs, small head with a red slit.
func _skitter(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_limb([Vector2(32, 66), Vector2(16, 78), Vector2(8, 88)], frame, 5.0)
	_limb([Vector2(38, 68), Vector2(26, 82), Vector2(22, 89)], frame, 5.0)
	_limb([Vector2(66, 68), Vector2(78, 80), Vector2(86, 89)], frame, 5.0)
	_limb([Vector2(72, 64), Vector2(88, 74), Vector2(94, 86)], frame, 5.0)
	_poly([Vector2(30, 62), Vector2(52, 52), Vector2(76, 58), Vector2(80, 68), Vector2(60, 74), Vector2(36, 72)], plate, edge)
	_poly([Vector2(14, 60), Vector2(30, 56), Vector2(33, 68), Vector2(18, 70)], plate, edge)
	draw_line(Vector2(17, 63), Vector2(27, 62), optic, 3.5)


## Upright broad-shouldered biped, slab chest plate, red visor bar.
func _hollow_warden(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(37, 58), Vector2(48, 58), Vector2(48, 88), Vector2(35, 88)], frame, edge)
	_poly([Vector2(52, 58), Vector2(63, 58), Vector2(65, 88), Vector2(52, 88)], frame, edge)
	_poly([Vector2(23, 34), Vector2(30, 34), Vector2(30, 68), Vector2(24, 68)], frame, edge)
	_poly([Vector2(70, 34), Vector2(77, 34), Vector2(76, 68), Vector2(70, 68)], frame, edge)
	_poly([Vector2(32, 22), Vector2(68, 22), Vector2(65, 62), Vector2(35, 62)], plate, edge)
	_poly([Vector2(20, 20), Vector2(34, 20), Vector2(34, 36), Vector2(22, 38)], plate, edge)
	_poly([Vector2(66, 20), Vector2(80, 20), Vector2(78, 38), Vector2(66, 36)], plate, edge)
	_poly([Vector2(41, 6), Vector2(59, 6), Vector2(61, 20), Vector2(39, 20)], frame, edge)
	draw_line(Vector2(50, 27), Vector2(50, 57), edge, 2.0)
	draw_rect(Rect2(43.0, 11.0, 14.0, 4.0), optic)


## Forward-leaning lean biped, swept-back spines with a red glow, one red slit.
func _rusher(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_limb([Vector2(52, 58), Vector2(42, 74), Vector2(32, 88)], frame, 6.0)
	_limb([Vector2(60, 58), Vector2(64, 74), Vector2(74, 88)], frame, 6.0)
	_limb([Vector2(40, 44), Vector2(26, 56), Vector2(18, 68)], frame, 5.0)
	_poly([Vector2(62, 32), Vector2(90, 20), Vector2(68, 46)], frame, edge)
	_poly([Vector2(66, 44), Vector2(94, 38), Vector2(68, 56)], frame, edge)
	draw_line(Vector2(66, 34), Vector2(88, 23), optic, 2.5)
	draw_line(Vector2(69, 47), Vector2(92, 40), optic, 2.5)
	_poly([Vector2(30, 34), Vector2(48, 28), Vector2(68, 46), Vector2(60, 62), Vector2(44, 60)], plate, edge)
	_poly([Vector2(16, 34), Vector2(30, 30), Vector2(34, 42), Vector2(20, 45)], plate, edge)
	draw_line(Vector2(18, 38), Vector2(28, 37), optic, 3.5)


## Huge hunched quadruped-stance brute, armored shoulders, red chest core.
func _siege_hulk(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(12, 52), Vector2(28, 52), Vector2(30, 88), Vector2(12, 88)], frame, edge)
	_poly([Vector2(32, 60), Vector2(44, 60), Vector2(46, 88), Vector2(32, 88)], frame, edge)
	_poly([Vector2(58, 60), Vector2(70, 60), Vector2(70, 88), Vector2(56, 88)], frame, edge)
	_poly([Vector2(72, 50), Vector2(90, 50), Vector2(90, 88), Vector2(72, 88)], frame, edge)
	_poly([Vector2(18, 34), Vector2(40, 22), Vector2(70, 26), Vector2(86, 44), Vector2(82, 68), Vector2(26, 70), Vector2(14, 54)], plate, edge)
	_poly([Vector2(10, 28), Vector2(44, 12), Vector2(54, 30), Vector2(18, 46)], plate.lightened(0.08), edge)
	_poly([Vector2(58, 20), Vector2(88, 22), Vector2(90, 42), Vector2(64, 40)], plate.lightened(0.08), edge)
	_poly([Vector2(4, 46), Vector2(18, 42), Vector2(20, 56), Vector2(6, 58)], frame, edge)
	draw_line(Vector2(7, 50), Vector2(16, 49), optic, 3.5)
	draw_circle(Vector2(52, 54), 8.0, edge)
	draw_circle(Vector2(52, 54), 5.5, optic)


func _poly(points: Array[Vector2], fill: Color, outline: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array(points)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, outline, 1.6, true)


func _limb(points: Array[Vector2], col: Color, width: float) -> void:
	draw_polyline(PackedVector2Array(points), col, width, true)


func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
