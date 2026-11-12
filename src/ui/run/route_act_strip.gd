class_name RouteActStrip
extends Control
## The act strip of the route screen (VARIETY_SPEC 11.2): one mark per wave of the run: a filled dot for a cleared wave, a
## ring with its number for the wave about to start, a hollow dot for the waves ahead, a diamond for a boss wave. Acts are
## separated by a wider gap. Information only (it takes no taps); the shapes carry the meaning, not the color.

const HEIGHT: float = 52.0

var wave_count: int = 15
var next_wave: int = 1
var boss_waves: PackedInt32Array = PackedInt32Array()
var act_ends: PackedInt32Array = PackedInt32Array()  ## wave numbers that close an act (a gap follows them)


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `next` = the wave the player is choosing for; waves before it are cleared.
func setup(count: int, next: int, content: ContentSet) -> void:
	wave_count = maxi(count, 1)
	next_wave = next
	boss_waves = PackedInt32Array()
	act_ends = PackedInt32Array()
	if content != null and content.run != null:
		for slot: WaveSlotDef in content.run.waves:
			if slot.kind == WaveSlotDef.Kind.BOSS:
				boss_waves.append(slot.index)
			var following: WaveSlotDef = content.run.wave_slot(slot.index + 1)
			if following != null and following.act != slot.act:
				act_ends.append(slot.index)
	else:
		for i: int in range(5, wave_count + 1, 5):
			boss_waves.append(i)
			act_ends.append(i)
	queue_redraw()


func _draw() -> void:
	if size.x < 20.0:
		return
	var h: bool = UiTheme.high_contrast_on()
	var cyan: Color = UiTheme.rim(&"warden_cyan", h)
	var amber: Color = UiTheme.rim(&"core_amber", h)
	var dim: Color = UiTheme.rim(&"gunmetal", h)
	var gap_extra: float = 14.0
	var step: float = (size.x - gap_extra * float(act_ends.size()) - 40.0) / float(maxi(wave_count - 1, 1))
	var x: float = 20.0
	var y: float = size.y * 0.5
	var font: Font = UiTheme.bold_font()
	for wave: int in range(1, wave_count + 1):
		var boss: bool = boss_waves.has(wave)
		var r: float = 15.0 if boss else 10.0
		var c: Vector2 = Vector2(x, y)
		if wave < next_wave:
			_mark(c, r, boss, cyan, true, 0.0)
		elif wave == next_wave:
			_mark(c, r + 7.0, boss, amber, false, 5.0)
			var label: String = str(wave)
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, RunUi.MIN_TEXT).x
			draw_string(font, Vector2(x - w * 0.5, y + 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, RunUi.MIN_TEXT, amber)
		else:
			_mark(c, r, boss, dim, false, 3.0)
		if wave < wave_count:
			var next_x: float = x + step + (gap_extra if act_ends.has(wave) else 0.0)
			draw_line(Vector2(x + r + 3.0, y), Vector2(next_x - r - 3.0, y), dim if wave >= next_wave else cyan, 2.0)
			x = next_x


func _mark(c: Vector2, r: float, diamond: bool, col: Color, filled: bool, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	if diamond:
		pts = PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0), c + Vector2(0.0, r), c + Vector2(-r, 0.0)])
	if filled:
		if diamond:
			draw_colored_polygon(pts, col)
		else:
			draw_circle(c, r, col)
		return
	draw_circle(c, r - 1.0, Color(0.0, 0.0, 0.0, 0.6))
	if diamond:
		pts.append(pts[0])
		draw_polyline(pts, col, width, true)
	else:
		draw_arc(c, r, 0.0, TAU, 32, col, width, true)
