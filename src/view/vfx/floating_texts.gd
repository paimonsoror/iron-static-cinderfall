class_name FloatingTexts
extends Node3D
## Pooled billboard `Label3D`s for the floating "+Scrap" numbers (ARCH 13: 24 in the pool, 12 alive on target).
## Each rises, pops in and fades over a fixed lifetime. When the active cap is reached the oldest text is reused.

const CAPACITY: int = 24
const LIFE_S: float = 0.9
const RISE_M: float = 1.5

var _labels: Array[Label3D] = []
var _live: PackedByteArray = PackedByteArray()
var _age: PackedFloat32Array = PackedFloat32Array()
var _base: PackedVector3Array = PackedVector3Array()
var _scale: PackedFloat32Array = PackedFloat32Array()
var _color: PackedColorArray = PackedColorArray()
var _cursor: int = 0
var _count: int = 0
var _cap: int = CAPACITY
var _outline: Color = Color(0.06, 0.09, 0.13, 1.0)


func setup() -> void:
	name = "FloatingTexts"
	_live.resize(CAPACITY)
	_age.resize(CAPACITY)
	_base.resize(CAPACITY)
	_scale.resize(CAPACITY)
	_color.resize(CAPACITY)
	for i: int in CAPACITY:
		var l: Label3D = Label3D.new()
		l.name = "Text%02d" % i
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.shaded = false
		l.double_sided = true
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.0085
		l.font_size = 64
		l.outline_size = 14
		l.render_priority = 8
		l.outline_render_priority = 7
		l.visible = false
		add_child(l)
		_labels.append(l)


## Limits how many texts may be alive at once (quality tiers); at most CAPACITY.
func set_cap(cap: int) -> void:
	_cap = clampi(cap, 1, CAPACITY)


func outline_color(c: Color) -> void:
	_outline = c


## Shows `text` at `world_pos`. `size` scales the text (1 = normal).
func spawn(text: String, world_pos: Vector3, size: float, color: Color) -> void:
	var i: int = _slot()
	if _live[i] == 0:
		_count += 1
	_live[i] = 1
	_age[i] = 0.0
	_base[i] = world_pos
	_scale[i] = size
	_color[i] = color
	var l: Label3D = _labels[i]
	l.text = text
	l.outline_modulate = _outline
	l.modulate = color
	l.position = world_pos
	l.visible = true


func step(delta: float) -> void:
	if _count == 0:
		return
	for i: int in CAPACITY:
		if _live[i] == 0:
			continue
		_age[i] += delta
		var l: Label3D = _labels[i]
		var t01: float = _age[i] / LIFE_S
		if t01 >= 1.0:
			_live[i] = 0
			_count -= 1
			l.visible = false
			continue
		var rise: float = 1.0 - pow(1.0 - t01, 2.0)
		l.position = _base[i] + Vector3(0.0, rise * RISE_M, 0.0)
		var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - t01 * 6.0)
		l.scale = Vector3.ONE * (_scale[i] * pop)
		var c: Color = _color[i]
		c.a = clampf(1.6 * (1.0 - t01), 0.0, 1.0)
		l.modulate = c
		var o: Color = _outline
		o.a = c.a
		l.outline_modulate = o


func live_count() -> int:
	return _count


## Text of a live slot, or "" (for tests).
func texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i: int in CAPACITY:
		if _live[i] == 1:
			out.append(_labels[i].text)
	return out


func clear() -> void:
	_live.fill(0)
	_count = 0
	_cursor = 0
	for l: Label3D in _labels:
		l.visible = false


## Next slot: a free one within the cap, else the oldest in the ring.
func _slot() -> int:
	if _count >= _cap:
		var oldest: int = -1
		var oldest_age: float = -1.0
		for i: int in CAPACITY:
			if _live[i] == 1 and _age[i] > oldest_age:
				oldest_age = _age[i]
				oldest = i
		if oldest >= 0:
			return oldest
	for n: int in CAPACITY:
		var i: int = (_cursor + n) % CAPACITY
		if _live[i] == 0:
			_cursor = (i + 1) % CAPACITY
			return i
	return _cursor
