class_name RunEnemyGlyph
extends Control
## A flat silhouette of one CHORUS machine for the route cards and the boss briefing (GDD 6): bone-ceramic plates over a dark
## gunmetal frame and ONE red optic (never a pair of eyes, never a skull). The four legacy types and the Siege Hulk are drawn
## by UiEnemyGlyph (a child); the new types are drawn here in the same 100 x 100 box. Unknown ids draw as a skitter.

const BOX: float = 100.0
const LEGACY: Array[StringName] = [&"skitter", &"hollow_warden", &"rusher", &"siege_hulk"]

var enemy_id: StringName = &"skitter"


func _init(id: StringName = &"skitter", px: float = 120.0) -> void:
	enemy_id = id
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if LEGACY.has(id) or not _drawn(id):
		var legacy: UiEnemyGlyph = UiEnemyGlyph.new(id if LEGACY.has(id) else &"skitter", px)
		UiKit.fill(legacy)
		add_child(legacy)


static func _drawn(id: StringName) -> bool:
	return [&"mote", &"shard", &"burster", &"spitter", &"splitter", &"shieldbearer", &"reclaimer", &"jammer", &"borer",
		&"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig", &"ward_pylon"].has(id)


func _draw() -> void:
	if LEGACY.has(enemy_id) or not _drawn(enemy_id):
		return
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
		&"mote":
			_mote(plate, frame, edge, optic)
		&"shard":
			_shard(plate, edge, optic)
		&"burster":
			_burster(plate, frame, edge, optic)
		&"spitter":
			_spitter(plate, frame, edge, optic)
		&"splitter":
			_splitter(plate, edge, optic)
		&"shieldbearer":
			_shieldbearer(plate, frame, edge, optic)
		&"reclaimer":
			_reclaimer(plate, frame, edge, optic)
		&"jammer":
			_jammer(plate, frame, edge, optic)
		&"borer":
			_borer(plate, frame, edge, optic)
		&"brood_carrier":
			_brood_carrier(plate, frame, edge, optic)
		&"lance_platform":
			_lance_platform(plate, frame, edge, optic)
		&"aegis_array", &"ward_pylon":
			_aegis_array(plate, frame, edge, optic)
		&"tremor_rig":
			_tremor_rig(plate, frame, edge, optic)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A hand-sized hopping tripod: a ceramic cap with a red slit.
func _mote(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_limb([Vector2(36, 62), Vector2(24, 78), Vector2(18, 90)], frame, 5.0)
	_limb([Vector2(50, 64), Vector2(50, 78), Vector2(50, 90)], frame, 5.0)
	_limb([Vector2(64, 62), Vector2(76, 78), Vector2(82, 90)], frame, 5.0)
	_poly([Vector2(26, 64), Vector2(32, 46), Vector2(50, 38), Vector2(68, 46), Vector2(74, 64)], plate, edge)
	draw_line(Vector2(40, 54), Vector2(60, 54), optic, 4.0)


func _shard(plate: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(50, 30), Vector2(68, 78), Vector2(32, 78)], plate, edge)
	draw_line(Vector2(44, 62), Vector2(56, 62), optic, 3.5)


## Hunched biped under a round hazard-striped tank wider than its body.
func _burster(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(52, 64), Vector2(62, 64), Vector2(62, 90), Vector2(50, 90)], frame, edge)
	_poly([Vector2(66, 64), Vector2(76, 64), Vector2(78, 90), Vector2(66, 90)], frame, edge)
	var hazard: Color = UiTheme.color(&"core_amber").lerp(edge, 0.25)
	draw_circle(Vector2(38, 46), 28.0, edge)
	draw_circle(Vector2(38, 46), 25.0, hazard)
	draw_line(Vector2(18, 38), Vector2(52, 66), edge, 5.0)
	draw_line(Vector2(14, 52), Vector2(42, 72), edge, 5.0)
	_poly([Vector2(50, 38), Vector2(72, 34), Vector2(80, 54), Vector2(74, 72), Vector2(54, 72)], plate, edge)
	_poly([Vector2(70, 18), Vector2(86, 22), Vector2(86, 38), Vector2(70, 38)], plate, edge)
	draw_line(Vector2(74, 28), Vector2(84, 28), optic, 3.5)


## A low crawler with a mortar tube raised over its back.
func _spitter(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_limb([Vector2(28, 74), Vector2(16, 84), Vector2(10, 90)], frame, 5.0)
	_limb([Vector2(40, 76), Vector2(34, 86), Vector2(32, 90)], frame, 5.0)
	_limb([Vector2(66, 76), Vector2(72, 86), Vector2(76, 90)], frame, 5.0)
	_limb([Vector2(76, 72), Vector2(88, 80), Vector2(94, 90)], frame, 5.0)
	_poly([Vector2(54, 60), Vector2(44, 26), Vector2(58, 20), Vector2(70, 56)], frame, edge)
	draw_circle(Vector2(51, 23), 8.0, plate)
	draw_circle(Vector2(51, 23), 4.5, edge)
	_poly([Vector2(20, 68), Vector2(40, 56), Vector2(78, 60), Vector2(82, 72), Vector2(60, 78), Vector2(26, 78)], plate, edge)
	draw_line(Vector2(24, 68), Vector2(34, 66), optic, 3.5)


## One frame, three shards: a faceted hull with seams.
func _splitter(plate: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(50, 18), Vector2(80, 36), Vector2(80, 68), Vector2(50, 86), Vector2(20, 68), Vector2(20, 36)], plate, edge)
	draw_line(Vector2(50, 18), Vector2(50, 52), edge, 2.5)
	draw_line(Vector2(50, 52), Vector2(20, 68), edge, 2.5)
	draw_line(Vector2(50, 52), Vector2(80, 68), edge, 2.5)
	draw_line(Vector2(42, 34), Vector2(58, 34), optic, 3.5)


## A biped behind a tall shield plate.
func _shieldbearer(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(52, 58), Vector2(62, 58), Vector2(62, 88), Vector2(50, 88)], frame, edge)
	_poly([Vector2(66, 58), Vector2(76, 58), Vector2(78, 88), Vector2(66, 88)], frame, edge)
	_poly([Vector2(48, 26), Vector2(80, 26), Vector2(80, 62), Vector2(50, 62)], plate, edge)
	_poly([Vector2(58, 8), Vector2(74, 8), Vector2(76, 24), Vector2(56, 24)], frame, edge)
	draw_rect(Rect2(61.0, 13.0, 12.0, 4.0), optic)
	_poly([Vector2(8, 22), Vector2(36, 14), Vector2(44, 50), Vector2(36, 86), Vector2(8, 78)], plate.lightened(0.1), edge)
	draw_line(Vector2(14, 30), Vector2(36, 24), edge, 2.0)
	draw_line(Vector2(14, 70), Vector2(36, 76), edge, 2.0)


## A biped with a repair arm and an antenna.
func _reclaimer(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(38, 60), Vector2(48, 60), Vector2(48, 88), Vector2(36, 88)], frame, edge)
	_poly([Vector2(52, 60), Vector2(62, 60), Vector2(64, 88), Vector2(52, 88)], frame, edge)
	_limb([Vector2(64, 40), Vector2(80, 36), Vector2(90, 22)], frame, 5.0)
	draw_circle(Vector2(90, 22), 5.0, plate)
	_limb([Vector2(36, 40), Vector2(24, 54), Vector2(22, 68)], frame, 5.0)
	_poly([Vector2(32, 28), Vector2(68, 28), Vector2(64, 62), Vector2(36, 62)], plate, edge)
	_poly([Vector2(42, 10), Vector2(58, 10), Vector2(60, 26), Vector2(40, 26)], frame, edge)
	draw_line(Vector2(50, 10), Vector2(50, 0), frame, 3.0)
	draw_line(Vector2(44, 18), Vector2(56, 18), optic, 3.5)


## A stilted dish on a mast: jams what it points at.
func _jammer(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_limb([Vector2(50, 60), Vector2(30, 76), Vector2(20, 90)], frame, 5.0)
	_limb([Vector2(50, 60), Vector2(70, 76), Vector2(80, 90)], frame, 5.0)
	_limb([Vector2(50, 60), Vector2(50, 90)], frame, 5.0)
	_poly([Vector2(36, 44), Vector2(64, 44), Vector2(60, 62), Vector2(40, 62)], plate, edge)
	_poly([Vector2(16, 14), Vector2(84, 14), Vector2(66, 38), Vector2(34, 38)], plate, edge)
	draw_line(Vector2(50, 38), Vector2(50, 44), frame, 4.0)
	draw_circle(Vector2(50, 22), 5.0, optic)


## A drill-nosed burrower on its side.
func _borer(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(26, 52), Vector2(72, 42), Vector2(90, 52), Vector2(74, 68), Vector2(28, 66)], plate, edge)
	_poly([Vector2(6, 60), Vector2(26, 50), Vector2(26, 68)], frame, edge)
	draw_line(Vector2(12, 60), Vector2(26, 56), edge, 2.0)
	draw_line(Vector2(12, 60), Vector2(26, 64), edge, 2.0)
	draw_line(Vector2(44, 44), Vector2(46, 66), edge, 2.0)
	draw_line(Vector2(62, 42), Vector2(62, 68), edge, 2.0)
	draw_line(Vector2(76, 50), Vector2(84, 50), optic, 3.5)
	_limb([Vector2(40, 66), Vector2(36, 80), Vector2(30, 88)], frame, 5.0)
	_limb([Vector2(66, 68), Vector2(72, 80), Vector2(78, 88)], frame, 5.0)


func _brood_carrier(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_limb([Vector2(18, 74), Vector2(8, 84), Vector2(6, 90)], frame, 6.0)
	_limb([Vector2(82, 74), Vector2(92, 84), Vector2(94, 90)], frame, 6.0)
	_poly([Vector2(8, 52), Vector2(28, 28), Vector2(72, 28), Vector2(92, 52), Vector2(86, 78), Vector2(14, 78)], plate, edge)
	for x: float in [30.0, 50.0, 70.0]:
		draw_circle(Vector2(x, 60.0), 8.0, edge)
		draw_circle(Vector2(x, 60.0), 5.0, frame)
	draw_line(Vector2(38, 38), Vector2(62, 38), optic, 4.0)


func _lance_platform(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_poly([Vector2(8, 66), Vector2(64, 58), Vector2(66, 80), Vector2(10, 86)], plate, edge)
	_poly([Vector2(40, 56), Vector2(94, 36), Vector2(98, 46), Vector2(48, 68)], frame, edge)
	_limb([Vector2(20, 84), Vector2(14, 90)], frame, 5.0)
	_limb([Vector2(58, 80), Vector2(64, 90)], frame, 5.0)
	draw_circle(Vector2(95, 41), 6.0, optic)


## A core ringed by its pylons.
func _aegis_array(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	for p: Vector2 in [Vector2(20, 30), Vector2(80, 30), Vector2(50, 84)]:
		draw_line(Vector2(50, 54), p, frame, 3.0)
		_poly([p + Vector2(-8, -10), p + Vector2(8, -10), p + Vector2(8, 10), p + Vector2(-8, 10)], plate, edge)
	draw_circle(Vector2(50, 54), 20.0, edge)
	draw_circle(Vector2(50, 54), 17.0, plate)
	draw_circle(Vector2(50, 54), 6.0, optic)


func _tremor_rig(plate: Color, frame: Color, edge: Color, optic: Color) -> void:
	_limb([Vector2(26, 62), Vector2(14, 76), Vector2(12, 90)], frame, 8.0)
	_limb([Vector2(74, 62), Vector2(86, 76), Vector2(88, 90)], frame, 8.0)
	_poly([Vector2(20, 34), Vector2(80, 34), Vector2(84, 62), Vector2(16, 62)], plate, edge)
	_poly([Vector2(40, 62), Vector2(60, 62), Vector2(62, 90), Vector2(38, 90)], frame, edge)
	draw_line(Vector2(34, 44), Vector2(66, 44), optic, 4.0)


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
