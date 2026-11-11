class_name LookDevTex
extends RefCounted
## The generated surface detail texture of the STYLISED_PLUS look (W3-C): 128 x 128, RGBA8, tileable, built in memory
## by integer hashing (no random generator, no file, no concept art), so it is identical on every run and device.
##   R  panel seams and rivets (1 = dark seam)      G  scratches and edge wear (1 = bare metal showing)
##   B  grime (value noise, 1 = clean)               A  1
## The shader reads it triplanar-lite in mesh space (LookDevActor shader), so it costs one texture fetch.

const SIZE: int = 128
const SEAMS_X: Array[int] = [9, 61, 102]
const SEAMS_Y: Array[int] = [5, 47, 88]
const SCRATCHES: int = 44

static var _tex: ImageTexture = null


## The shared texture (built once).
static func texture() -> ImageTexture:
	if _tex == null:
		_tex = ImageTexture.create_from_image(image())
	return _tex


## The CPU image with mipmaps; the same bytes on every call.
static func image() -> Image:
	var px: PackedByteArray = PackedByteArray()
	px.resize(SIZE * SIZE * 4)
	for y: int in SIZE:
		for x: int in SIZE:
			var o: int = (y * SIZE + x) * 4
			px[o] = _byte(_seam(x, y))
			px[o + 1] = 0
			px[o + 2] = _byte(_grime(x, y))
			px[o + 3] = 255
	for k: int in SCRATCHES:
		_scratch(px, k)
	var img: Image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, px)
	img.generate_mipmaps()
	return img


## FNV-1a of the pixel bytes of mip 0 (the test pins this number).
static func checksum() -> int:
	var img: Image = image()
	var data: PackedByteArray = img.get_data()
	var h: int = 0x4bf29ce484222325
	for i: int in SIZE * SIZE * 4:
		h = ((h ^ data[i]) * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF
	return h


static func _seam(x: int, y: int) -> float:
	var v: float = 0.0
	for sx: int in SEAMS_X:
		var dx: int = absi(x - sx)
		if dx <= 1 and _hash(sx, y >> 3, 3) > 9000:
			v = maxf(v, 1.0 if dx == 0 else 0.45)
	for sy: int in SEAMS_Y:
		var dy: int = absi(y - sy)
		if dy <= 1 and _hash(x >> 3, sy, 5) > 9000:
			v = maxf(v, 1.0 if dy == 0 else 0.45)
	for sx2: int in SEAMS_X:
		for sy2: int in SEAMS_Y:
			if absi(x - (sx2 + 6)) <= 1 and absi(y - (sy2 + 6)) <= 1:
				v = maxf(v, 0.9)
	return v


static func _grime(x: int, y: int) -> float:
	var n: float = 0.55 * _noise(x, y, 32, 11) + 0.3 * _noise(x, y, 16, 17) + 0.15 * _noise(x, y, 8, 23)
	return clampf((n - 0.15) * 1.5, 0.0, 1.0)


## Tileable value noise: lattice cells of `cell` pixels wrap around the texture.
static func _noise(x: int, y: int, cell: int, salt: int) -> float:
	var cells: int = floori(float(SIZE) / float(cell))
	var fx: float = float(x) / float(cell)
	var fy: float = float(y) / float(cell)
	var x0: int = floori(fx)
	var y0: int = floori(fy)
	var tx: float = smoothstep(0.0, 1.0, fx - float(x0))
	var ty: float = smoothstep(0.0, 1.0, fy - float(y0))
	var a: float = _unit(x0 % cells, y0 % cells, salt)
	var b: float = _unit((x0 + 1) % cells, y0 % cells, salt)
	var c: float = _unit(x0 % cells, (y0 + 1) % cells, salt)
	var d: float = _unit((x0 + 1) % cells, (y0 + 1) % cells, salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## One scratch: a short straight streak starting at a hashed place, mostly axis aligned, wrapping at the borders.
static func _scratch(px: PackedByteArray, k: int) -> void:
	var x: float = float(_hash(k, 1, 31) % SIZE)
	var y: float = float(_hash(k, 2, 37) % SIZE)
	var kind: int = _hash(k, 3, 41) % 4
	var dir: Vector2 = Vector2.RIGHT
	match kind:
		1:
			dir = Vector2.DOWN
		2:
			dir = Vector2(1.0, 1.0).normalized()
		3:
			dir = Vector2(1.0, -0.5).normalized()
	var length: int = 7 + _hash(k, 4, 43) % 22
	var strength: float = 0.45 + 0.55 * _unit(k, 5, 47)
	for i: int in length:
		var fade: float = 1.0 - float(i) / float(length)
		var ix: int = posmod(roundi(x + dir.x * float(i)), SIZE)
		var iy: int = posmod(roundi(y + dir.y * float(i)), SIZE)
		var o: int = (iy * SIZE + ix) * 4 + 1
		px[o] = maxi(px[o], _byte(strength * (0.4 + 0.6 * fade)))


static func _byte(v: float) -> int:
	return clampi(roundi(v * 255.0), 0, 255)


static func _unit(x: int, y: int, salt: int) -> float:
	return float(_hash(x, y, salt)) / 65535.0


static func _hash(x: int, y: int, salt: int) -> int:
	var h: int = (x * 374761393 + y * 668265263 + salt * 1442695041) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return h & 0xFFFF
