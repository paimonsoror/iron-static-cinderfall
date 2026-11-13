class_name FxStatic
extends CanvasLayer
## The Static Front overlay (VARIETY_SPEC 12.3 `fx_static_overlay`; V4-X): a HUD-space pattern on the LEFT and RIGHT edges of the screen
## (8 percent of the width each), never over the centre of the battlefield. Warning (the 6 s `warn_s` of the event): red diagonal hatch,
## fading in and breathing slowly, the same hatch language as every danger decal. Active (the 12 s of the front): grey static, three
## pre-built noise frames cycled at 12 Hz. Reduced Flash (GDD 10.3) holds one still frame at a steady strength: nothing flickers. Textures are
## generated once (no shader, so there is nothing new to warm); the strips are two `TextureRect`s that tile the texture, and each frame only
## their `modulate` changes. `FxChaos` calls `warned`, `started`, `ended` from the event signals; `step` also follows
## `EventState.ability_lock_ticks` of the bound sim, so a front that is already running when the view binds (resume) is drawn too.

const EDGE_FRACTION: float = 0.08
const NOISE_FRAMES: int = 3
const FRAME_S: float = 1.0 / 12.0
const WARN_PEAK: float = 0.42
const ACTIVE_ALPHA: float = 0.34
const TEX: int = 64
const FRONT_ID: StringName = &"static_front"

var left: TextureRect
var right: TextureRect

var _noise: Array[ImageTexture] = []
var _hatch: ImageTexture
var _phase: int = 0  ## 0 off, 1 warning, 2 active
var _by_event: bool = false
var _warn_total: float = 0.0
var _warn_left: float = 0.0
var _t: float = 0.0
var _reduced: bool = false
var _red: Color = Color(0.85, 0.3, 0.3)


func setup(chorus_red: Color) -> void:
	name = "StaticOverlay"
	layer = 0
	_red = chorus_red
	_hatch = MatLib.hatch_texture()
	for k: int in NOISE_FRAMES:
		_noise.append(_make_noise(k))
	left = _strip("StaticLeft", 0.0, EDGE_FRACTION)
	right = _strip("StaticRight", 1.0 - EDGE_FRACTION, 1.0)
	_show(false)


func set_reduced(on: bool) -> void:
	_reduced = on


## `event_warned(id, ticks, x, z)`.
func warned(event_id: StringName, ticks: int, _x: float, _z: float) -> void:
	if event_id != FRONT_ID:
		return
	_phase = 1
	_by_event = true
	_warn_total = maxf(float(ticks) * SimWorld.DT, 0.05)
	_warn_left = _warn_total
	_show(true)


## `event_started(id)`.
func started(event_id: StringName) -> void:
	if event_id == FRONT_ID:
		_phase = 2
		_by_event = true
		_show(true)


## `event_ended(id)` (also a cancelled front).
func ended(event_id: StringName) -> void:
	if event_id == FRONT_ID:
		clear()


func step(delta: float, locked_ticks: int) -> void:
	_t += delta
	if _phase == 0 and locked_ticks > 0:
		_phase = 2  # a front that was already running when the view bound: the lock decides when it is over
		_by_event = false
		_show(true)
	elif _phase == 2 and not _by_event and locked_ticks <= 0:
		clear()
		return
	match _phase:
		1:
			_warn_left -= delta
			var ramp: float = clampf(1.0 - _warn_left / _warn_total, 0.0, 1.0)
			var breath: float = 1.0 if _reduced else 0.8 + 0.2 * sin(_t * 3.0)
			_paint(_hatch, _red, WARN_PEAK * ramp * breath)
		2:
			var frame: int = 0 if _reduced else int(_t / FRAME_S) % NOISE_FRAMES
			_paint(_noise[frame], Color(0.82, 0.88, 0.92), ACTIVE_ALPHA)


func is_showing() -> bool:
	return _phase != 0


func phase() -> int:
	return _phase


func clear() -> void:
	_phase = 0
	_show(false)


func _show(on: bool) -> void:
	left.visible = on
	right.visible = on


func _paint(tex: ImageTexture, tint: Color, alpha: float) -> void:
	for strip: TextureRect in [left, right]:
		strip.texture = tex
		strip.modulate = Color(tint.r, tint.g, tint.b, alpha)


func _strip(strip_name: String, from: float, to: float) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.name = strip_name
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	r.anchor_left = from
	r.anchor_right = to
	r.anchor_top = 0.0
	r.anchor_bottom = 1.0
	r.offset_left = 0.0
	r.offset_right = 0.0
	r.offset_top = 0.0
	r.offset_bottom = 0.0
	add_child(r)
	return r


## One frame of grey static: scan lines of random strength and white specks (white, alpha only: the tint colours it).
func _make_noise(seed_n: int) -> ImageTexture:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7000 + seed_n
	var img: Image = Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	for y: int in TEX:
		var line: float = rng.randf_range(0.1, 0.65)
		for x: int in TEX:
			var speck: float = 0.9 if rng.randf() < 0.07 else 0.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(line * rng.randf_range(0.5, 1.0), speck)))
	return ImageTexture.create_from_image(img)
