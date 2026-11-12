class_name EnvTex
extends RefCounted
## The generated floor detail tile of the gritty yard (W3-E): 128 x 128, RGBA8, tileable, covering 1.8 x 1.5 m. Built in memory by
## integer value noise and integer random walks only (no float in the generator, no random generator, no file, no concept art), so the
## bytes are identical on every run and device. The checksum is pinned by a test.
##   R  grain (mottled asphalt, mid grey = neutral)     G  cracks and pits (1 = crack)
##   B  low-frequency blotches (puddles, stains)         A  streak breakup (fine noise)
## The floor shader reads it once per pixel (plus two cheap macro fetches).

const SIZE: int = 128
const TILE_M: Vector2 = Vector2(1.8, 1.5)
const CRACKS: int = 8
const PITS: int = 90

## Sixteen unit directions scaled by 256 (22.5 degrees apart): integer walks never touch a float.
const DIRS: Array[Vector2i] = [
	Vector2i(256, 0), Vector2i(237, 98), Vector2i(181, 181), Vector2i(98, 237),
	Vector2i(0, 256), Vector2i(-98, 237), Vector2i(-181, 181), Vector2i(-237, 98),
	Vector2i(-256, 0), Vector2i(-237, -98), Vector2i(-181, -181), Vector2i(-98, -237),
	Vector2i(0, -256), Vector2i(98, -237), Vector2i(181, -181), Vector2i(237, -98),
]

static var _tex: ImageTexture = null


## The shared texture (built once, with mipmaps).
static func texture() -> ImageTexture:
	if _tex == null:
		_tex = ImageTexture.create_from_image(image())
	return _tex


## The CPU image with mipmaps; the same bytes on every call.
static func image() -> Image:
	var grain_a: PackedByteArray = _octave(5, 11)
	var grain_b: PackedByteArray = _octave(4, 17)
	var grain_c: PackedByteArray = _octave(3, 23)
	var blotch_a: PackedByteArray = _octave(5, 29)
	var blotch_b: PackedByteArray = _octave(4, 31)
	var fine: PackedByteArray = _octave(2, 37)
	var cracks: PackedByteArray = PackedByteArray()
	cracks.resize(SIZE * SIZE)
	for k: int in CRACKS:
		var start: int = _hash(k, 1, 41)
		_crack(cracks, k * 7 + 1, start % SIZE, (start >> 7) % SIZE, (start >> 3) % 16, 38 + start % 50, 0)
	for k: int in PITS:
		var at: int = _hash(k, 2, 43) % (SIZE * SIZE)
		cracks[at] = maxi(cracks[at], 70 + _hash(k, 3, 47) % 70)
	var px: PackedByteArray = PackedByteArray()
	px.resize(SIZE * SIZE * 4)
	for i: int in SIZE * SIZE:
		var o: int = i * 4
		var g: int = ((grain_a[i] * 128 + grain_b[i] * 77 + grain_c[i] * 51) >> 8) + (_hash(i, 5, 53) & 15) - 8
		px[o] = clampi(g, 0, 255)
		px[o + 1] = cracks[i]
		px[o + 2] = (blotch_a[i] * 154 + blotch_b[i] * 102) >> 8
		px[o + 3] = fine[i]
	var img: Image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, px)
	img.generate_mipmaps()
	return img


## FNV-1a of the pixel bytes of mip 0 (the test pins this number).
static func checksum() -> int:
	var data: PackedByteArray = image().get_data()
	var h: int = 0x4bf29ce484222325
	for i: int in SIZE * SIZE * 4:
		h = ((h ^ data[i]) * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF
	return h


## Tileable smooth value noise on a lattice of (1 << shift) pixel cells, integer arithmetic only: one byte per pixel.
static func _octave(shift: int, salt: int) -> PackedByteArray:
	var cell: int = 1 << shift
	var cells: int = SIZE >> shift
	var lat: PackedByteArray = PackedByteArray()
	lat.resize(cells * cells)
	for i: int in cells * cells:
		lat[i] = _hash(i % cells, i >> (7 - shift), salt) & 255
	var wt: PackedInt32Array = PackedInt32Array()
	for i: int in cell:
		var t: int = (i << 8) >> shift
		wt.append((t * t * (768 - 2 * t)) >> 16)
	var out: PackedByteArray = PackedByteArray()
	out.resize(SIZE * SIZE)
	var mask: int = cell - 1
	for y: int in SIZE:
		var r0: int = (y >> shift) * cells
		var r1: int = (((y >> shift) + 1) % cells) * cells
		var wy: int = wt[y & mask]
		for x: int in SIZE:
			var c0: int = x >> shift
			var c1: int = (c0 + 1) % cells
			var wx: int = wt[x & mask]
			var top: int = lat[r0 + c0] * (256 - wx) + lat[r0 + c1] * wx
			var bot: int = lat[r1 + c0] * (256 - wx) + lat[r1 + c1] * wx
			out[y * SIZE + x] = (top * (256 - wy) + bot * wy) >> 16
	return out


## One crack: an integer random walk that turns now and then, wraps around the tile and may fork once.
static func _crack(g: PackedByteArray, id: int, x0: int, y0: int, dir: int, steps: int, depth: int) -> void:
	var fx: int = x0 << 8
	var fy: int = y0 << 8
	var d: int = dir
	for i: int in steps:
		fx += DIRS[d].x
		fy += DIRS[d].y
		var px: int = posmod(fx >> 8, SIZE)
		var py: int = posmod(fy >> 8, SIZE)
		var h: int = _hash(id, i, 59 + depth)
		var strength: int = 255 if depth == 0 else 200
		g[py * SIZE + px] = maxi(g[py * SIZE + px], strength)
		if (h & 3) == 0:
			var side: int = posmod(py + 1, SIZE) * SIZE + px
			g[side] = maxi(g[side], 120)
		if (h >> 4) % 7 == 0:
			d = (d + 1 + 14 * ((h >> 9) & 1)) % 16
		if depth == 0 and i > 6 and (h >> 8) % 19 == 0:
			_crack(g, id * 31 + i, px, py, (d + 3 + 10 * ((h >> 11) & 1)) % 16, (steps - i) >> 1, 1)


static func _hash(x: int, y: int, salt: int) -> int:
	var h: int = (x * 374761393 + y * 668265263 + salt * 1442695041) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return h & 0xFFFF
