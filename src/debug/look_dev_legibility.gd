extends SceneTree
## 1x legibility score of the Warden (W3-C round 3). Input: captures of the same frame WITH the Warden (any look) and WITHOUT
## it (`look_dev_sandbox --hide-warden`); the sim is deterministic and the look does not touch it, so one background capture
## serves every look. The Warden pixels are the pixels that differ between the pair inside a search box (the biggest blob after a 1 px opening,
## which drops rain streaks, muzzle-flash spikes and the tracer); the ring is the
## background (from the capture without the Warden) 3 to 9 px outside the silhouette. Headless, Image API only.
##   Godot --headless --path <project> --script res://src/debug/look_dev_legibility.gd -- --without=<png> --box=x,y,w,h \
##        --with=LABEL|<png> [--with=LABEL|<png> ...]
## Printed per label (luma = Rec. 709 on the sRGB values, 0..1):
##   px           Warden pixels in the silhouette
##   luma_w       mean luma of those pixels            luma_ring   mean luma of the ring
##   contrast     |luma_w - luma_ring|                  pixel_contrast  mean over the pixels of |luma - luma_ring|
##   p10 / p90    10th and 90th percentile luma of the Warden pixels
##   color_dist   distance between the mean RGB of the Warden pixels and of the ring (0..1.73)
##   clipped      share of Warden pixels with any channel >= 250 / 255 (includes saturated cyan)
##   white        share of Warden pixels with every channel >= 240 / 255 (blown-out white)
##   outside_diff share of the pixels outside the box that differ between the pair (rain streaks and the tracer: a few tenths
##                of a percent when the pair is aligned)
## `--dump=<dir>` also writes <dir>/<label>_mask.png (grey = Warden pixel, green = clipped channel, white = blown-out white,
## red = difference outside the box).

const DIFF_THRESHOLD: float = 6.0 / 255.0
const RING_IN: int = 3
const RING_OUT: int = 9
const CLIP: float = 250.0 / 255.0
const WHITE: float = 240.0 / 255.0


func _init() -> void:
	var without_path: String = ""
	var box: Rect2i = Rect2i(215, 1402, 100, 80)
	var withs: Array[PackedStringArray] = []
	var dump_dir: String = ""
	for raw: String in OS.get_cmdline_user_args():
		var eq: int = raw.find("=")
		if eq < 0:
			continue
		var key: String = raw.substr(0, eq)
		var value: String = raw.substr(eq + 1)
		match key:
			"--without":
				without_path = value
			"--box":
				var p: PackedStringArray = value.split(",")
				box = Rect2i(p[0].to_int(), p[1].to_int(), p[2].to_int(), p[3].to_int())
			"--dump":
				dump_dir = value
			"--with":
				var bar: int = value.find("|")
				withs.append(PackedStringArray([value.substr(0, bar), value.substr(bar + 1)]))
	var bg: Image = Image.load_from_file(without_path)
	if bg == null:
		print("LEGIBILITY ERROR cannot read %s" % without_path)
		quit(2)
		return
	for pair: PackedStringArray in withs:
		var img: Image = Image.load_from_file(pair[1])
		if img == null:
			print("LEGIBILITY ERROR cannot read %s" % pair[1])
			continue
		print(_score(pair[0], img, bg, box, dump_dir))
	quit(0)


func _score(label: String, img: Image, bg: Image, box: Rect2i, dump_dir: String) -> String:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var outside: int = 0
	var dump: Image = null
	if dump_dir != "":
		dump = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			if box.has_point(Vector2i(x, y)):
				continue
			if _differs(img.get_pixel(x, y), bg.get_pixel(x, y)):
				outside += 1
				if dump != null:
					dump.fill_rect(Rect2i(x - 2, y - 2, 5, 5), Color.RED)
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(box.size.x * box.size.y)
	for by: int in box.size.y:
		for bx: int in box.size.x:
			var pos: Vector2i = box.position + Vector2i(bx, by)
			if _differs(img.get_pixel(pos.x, pos.y), bg.get_pixel(pos.x, pos.y)):
				raw[by * box.size.x + bx] = 1
	# an opening drops thin things (rain streaks, flash spikes, the tracer); the biggest blob left is the Warden
	var mask: PackedByteArray = _largest(_grow(_shrink(raw, box.size), box.size), box.size)
	var pixels: Array[Vector2i] = []
	for by: int in box.size.y:
		for bx: int in box.size.x:
			if mask[by * box.size.x + bx] == 1:
				pixels.append(Vector2i(bx, by))
				if dump != null:
					dump.set_pixel(box.position.x + bx, box.position.y + by, Color(0.45, 0.45, 0.45))
	var near_in: PackedByteArray = _stamp(pixels, box.size, RING_IN)
	var near_out: PackedByteArray = _stamp(pixels, box.size, RING_OUT)
	var ring_luma: float = 0.0
	var ring_rgb: Vector3 = Vector3.ZERO
	var ring_n: int = 0
	for i: int in mask.size():
		if near_out[i] == 1 and near_in[i] == 0 and mask[i] == 0:
			var rc: Color = bg.get_pixel(box.position.x + i % box.size.x, box.position.y + floori(float(i) / float(box.size.x)))
			ring_luma += _luma(rc)
			ring_rgb += Vector3(rc.r, rc.g, rc.b)
			ring_n += 1
	if pixels.is_empty() or ring_n == 0:
		return "LEGIBILITY %s px=%d ring=%d (nothing to score)" % [label, pixels.size(), ring_n]
	ring_luma /= float(ring_n)
	ring_rgb /= float(ring_n)
	var lumas: PackedFloat32Array = PackedFloat32Array()
	var sum_luma: float = 0.0
	var sum_abs: float = 0.0
	var rgb: Vector3 = Vector3.ZERO
	var clipped: int = 0
	var white: int = 0
	for p: Vector2i in pixels:
		var c: Color = img.get_pixel(box.position.x + p.x, box.position.y + p.y)
		var l: float = _luma(c)
		lumas.append(l)
		sum_luma += l
		sum_abs += absf(l - ring_luma)
		rgb += Vector3(c.r, c.g, c.b)
		if c.r >= CLIP or c.g >= CLIP or c.b >= CLIP:
			clipped += 1
			if dump != null:
				dump.set_pixel(box.position.x + p.x, box.position.y + p.y, Color.GREEN)
		if c.r >= WHITE and c.g >= WHITE and c.b >= WHITE:
			white += 1
			if dump != null:
				dump.set_pixel(box.position.x + p.x, box.position.y + p.y, Color.WHITE)
	if dump != null:
		dump.save_png("%s/%s_mask.png" % [dump_dir, label])
	var n: float = float(pixels.size())
	lumas.sort()
	var mean_luma: float = sum_luma / n
	return "LEGIBILITY %s px=%d luma_w=%.3f luma_ring=%.3f contrast=%.3f pixel_contrast=%.3f p10=%.3f p90=%.3f color_dist=%.3f clipped=%.1f%% white=%.1f%% outside_diff=%.2f%%" % [
		label, pixels.size(), mean_luma, ring_luma, absf(mean_luma - ring_luma), sum_abs / n,
		lumas[floori(n * 0.1)], lumas[mini(floori(n * 0.9), lumas.size() - 1)], (rgb / n - ring_rgb).length(),
		100.0 * float(clipped) / n, 100.0 * float(white) / n, 100.0 * float(outside) / (float(w * h) / 4.0)
	]


func _differs(a: Color, b: Color) -> bool:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) > DIFF_THRESHOLD


func _luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


## 1 for every cell within `radius` of a listed pixel (stamped disks).
func _stamp(pixels: Array[Vector2i], size: Vector2i, radius: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(size.x * size.y)
	var r2: int = radius * radius
	for p: Vector2i in pixels:
		for dy: int in range(-radius, radius + 1):
			var y: int = p.y + dy
			if y < 0 or y >= size.y:
				continue
			for dx: int in range(-radius, radius + 1):
				var x: int = p.x + dx
				if x < 0 or x >= size.x or dx * dx + dy * dy > r2:
					continue
				out[y * size.x + x] = 1
	return out


func _neighbour_all(m: PackedByteArray, size: Vector2i, x: int, y: int, want: int) -> bool:
	var hit: bool = false
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + o.x
		var ny: int = y + o.y
		var v: int = 0
		if nx >= 0 and ny >= 0 and nx < size.x and ny < size.y:
			v = m[ny * size.x + nx]
		if want == 1 and v == 0:
			return false
		if want == 0 and v == 1:
			hit = true
	return hit if want == 0 else true


func _shrink(m: PackedByteArray, size: Vector2i) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(m.size())
	for y: int in size.y:
		for x: int in size.x:
			out[y * size.x + x] = 1 if _neighbour_all(m, size, x, y, 1) else 0
	return out


func _grow(m: PackedByteArray, size: Vector2i) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(m.size())
	for y: int in size.y:
		for x: int in size.x:
			out[y * size.x + x] = 1 if _neighbour_all(m, size, x, y, 0) else 0
	return out


## The biggest 4-connected blob of a mask.
func _largest(m: PackedByteArray, size: Vector2i) -> PackedByteArray:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(m.size())
	var best: PackedInt32Array = PackedInt32Array()
	for start: int in m.size():
		if m[start] == 0 or seen[start] == 1:
			continue
		var blob: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var head: int = 0
		while head < blob.size():
			var i: int = blob[head]
			head += 1
			var x: int = i % size.x
			var y: int = floori(float(i) / float(size.x))
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
					continue
				var ni: int = ny * size.x + nx
				if m[ni] == 1 and seen[ni] == 0:
					seen[ni] = 1
					blob.append(ni)
		if blob.size() > best.size():
			best = blob
	var out: PackedByteArray = PackedByteArray()
	out.resize(m.size())
	for i: int in best:
		out[i] = 1
	return out
