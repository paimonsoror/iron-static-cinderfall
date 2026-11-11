extends SceneTree
## Look-dev comparison sheet (W3-C): crops, scales and lays PNGs side by side with a bitmap-font label above each.
##   Godot --headless --path <project> --script res://src/debug/look_dev_compare.gd -- --out=<png> --img=LABEL|<png> ...
##        [--crop=x,y,w,h] [--scale=<int>] [--pad=<px>] [--rows=<n>] [--plain]
## `--plain` writes the single input image as it is (no label, no padding); an output name ending in .jpg is saved as a
## JPEG (quality 0.88) instead of a PNG, which is how the full-size individual captures are kept small.
## Pure Image API (no rendering, works headless); the glyphs are a 5 x 7 font drawn with rectangles.

const FONT_SCALE: int = 3
const BG: Color = Color(0.063, 0.094, 0.125, 1.0)
const FG: Color = Color(0.85, 0.86, 0.82, 1.0)
const GLYPHS: Dictionary[String, Array] = {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"D": [30, 17, 17, 17, 17, 17, 30], "E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 25, 21, 19, 17, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 27, 17], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31],
	"3": [30, 1, 1, 14, 1, 1, 30], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 2, 12], "+": [0, 4, 4, 31, 4, 4, 0], "-": [0, 0, 0, 31, 0, 0, 0],
	"_": [0, 0, 0, 0, 0, 0, 31], ".": [0, 0, 0, 0, 0, 12, 12], "=": [0, 31, 0, 31, 0, 0, 0],
	" ": [0, 0, 0, 0, 0, 0, 0], ":": [0, 12, 12, 0, 12, 12, 0],
}


func _init() -> void:
	var out: String = ""
	var labels: PackedStringArray = PackedStringArray()
	var paths: PackedStringArray = PackedStringArray()
	var crop: Rect2i = Rect2i()
	var scale: int = 1
	var pad: int = 10
	var rows: int = 1
	var plain: bool = false
	for raw: String in OS.get_cmdline_user_args():
		if raw == "--plain":
			plain = true
		var eq: int = raw.find("=")
		if eq < 0:
			continue
		var key: String = raw.substr(0, eq)
		var value: String = raw.substr(eq + 1)
		match key:
			"--out":
				out = value
			"--img":
				var bar: int = value.find("|")
				labels.append(value.substr(0, bar))
				paths.append(value.substr(bar + 1))
			"--crop":
				var p: PackedStringArray = value.split(",")
				crop = Rect2i(p[0].to_int(), p[1].to_int(), p[2].to_int(), p[3].to_int())
			"--scale":
				scale = maxi(1, value.to_int())
			"--pad":
				pad = value.to_int()
			"--rows":
				rows = maxi(1, value.to_int())
	var tiles: Array[Image] = []
	for path: String in paths:
		var img: Image = Image.load_from_file(path)
		if img == null:
			print("COMPARE ERROR cannot read %s" % path)
			quit(2)
			return
		if crop.size.x > 0:
			img = img.get_region(crop)
		if scale > 1:
			img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
		tiles.append(img)
	if tiles.is_empty() or out == "":
		print("COMPARE ERROR nothing to do")
		quit(2)
		return
	if plain:
		_save(tiles[0], out)
		return
	var header: int = 7 * FONT_SCALE + 2 * pad
	var per_row: int = ceili(float(tiles.size()) / float(rows))
	var cell_w: int = tiles[0].get_width()
	var cell_h: int = tiles[0].get_height()
	var sheet: Image = Image.create(
		per_row * cell_w + (per_row + 1) * pad, rows * (cell_h + header) + pad, false, Image.FORMAT_RGB8
	)
	sheet.fill(BG)
	var half: int = floori(float(pad) * 0.5)
	for i: int in tiles.size():
		var col: int = i % per_row
		var row: int = floori(float(i) / float(per_row))
		var x: int = pad + col * (cell_w + pad)
		var y: int = pad + row * (cell_h + header)
		_text(sheet, labels[i], x, y + half)
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()), Vector2i(x, y + header - half))
	_save(sheet, out)


func _save(img: Image, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var err: int = img.save_jpg(out, 0.88) if out.ends_with(".jpg") else img.save_png(out)
	print("COMPARE %s %dx%d err=%d" % [out, img.get_width(), img.get_height(), err])
	quit(0 if err == OK else 3)


func _text(img: Image, text: String, x: int, y: int) -> void:
	var cx: int = x
	for ch: String in text.to_upper():
		var rows: Array = GLYPHS.get(ch, GLYPHS[" "])
		for r: int in 7:
			var bits: int = rows[r]
			for c: int in 5:
				if ((bits >> (4 - c)) & 1) == 1:
					img.fill_rect(Rect2i(cx + c * FONT_SCALE, y + r * FONT_SCALE, FONT_SCALE, FONT_SCALE), FG)
		cx += 6 * FONT_SCALE
