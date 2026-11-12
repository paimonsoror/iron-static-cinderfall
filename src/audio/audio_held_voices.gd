class_name AudioHeldVoices
extends RefCounted
## Held voices (VARIETY_SPEC 13.7): one looping voice per weapon slot, started and stopped by the id of a sound (a spin-up
## rattle or a torch hiss that lasts as long as the weapon fires). They are players of their own, outside the 16-voice
## pool, so a held loop never takes a voice from the sounds that matter and the pool can never be starved by them; there are
## only SLOTS of them. A release fades the loop out over FADE_SECONDS (a loop cut mid-wave clicks); the director calls
## `advance` every frame. The streams must be looping copies (AudioLoopPad.looped_copy): that is what keeps the
## wrap inside the buffer on a phone.

const SLOTS: int = 2
const FADE_SECONDS: float = 0.08
const SILENT_DB: float = -80.0

var players: Array[AudioStreamPlayer] = []
var ids: Array[StringName] = []  ## the id each slot holds (&"" = free); a fading slot still names its id

var _base_db: PackedFloat32Array = PackedFloat32Array()
var _fade_left: PackedFloat32Array = PackedFloat32Array()  ## > 0 while the slot fades out


## Creates the SLOTS players under `parent` on `bus`.
func build(parent: Node, bus: StringName) -> void:
	for i: int in SLOTS:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = SILENT_DB
		parent.add_child(p)
		players.append(p)
		ids.append(&"")
		@warning_ignore("return_value_discarded")
		_base_db.append(0.0)
		@warning_ignore("return_value_discarded")
		_fade_left.append(0.0)


## Starts `stream` in `slot`, or keeps it when the slot already holds `id` (a fading hold is taken back at full volume).
## False for a bad slot or a null stream.
func start(slot: int, id: StringName, stream: AudioStream, volume_db: float) -> bool:
	if slot < 0 or slot >= players.size() or stream == null:
		return false
	var p: AudioStreamPlayer = players[slot]
	if ids[slot] == id and (p.playing or p.stream_paused):
		_fade_left[slot] = 0.0
		_base_db[slot] = volume_db
		p.volume_db = volume_db
		return true
	p.stop()
	p.stream_paused = false
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()
	ids[slot] = id
	_base_db[slot] = volume_db
	_fade_left[slot] = 0.0
	return true


## Fades the slot out (or stops it at once when `immediate`, or when it is frozen by a pause).
func release(slot: int, immediate: bool = false) -> void:
	if slot < 0 or slot >= players.size() or ids[slot] == &"":
		return
	var p: AudioStreamPlayer = players[slot]
	if immediate or p.stream_paused or not p.playing:
		_stop(slot)
	elif _fade_left[slot] <= 0.0:
		_fade_left[slot] = FADE_SECONDS


func release_all(immediate: bool = false) -> void:
	for slot: int in players.size():
		release(slot, immediate)


## One frame of the fades. A finished fade stops the voice.
func advance(dt: float) -> void:
	for slot: int in players.size():
		if _fade_left[slot] <= 0.0:
			continue
		_fade_left[slot] -= dt
		if _fade_left[slot] <= 0.0:
			_stop(slot)
		else:
			var level: float = _fade_left[slot] / FADE_SECONDS
			players[slot].volume_db = maxf(_base_db[slot] + linear_to_db(maxf(level, 0.0001)), SILENT_DB)


## The slot holds a sound that has not been released (a fading slot does not count).
func is_held(slot: int) -> bool:
	return slot >= 0 and slot < players.size() and ids[slot] != &"" and _fade_left[slot] <= 0.0


## The slot's voice is sounding (or frozen by a pause), fading or not.
func is_sounding(slot: int) -> bool:
	if slot < 0 or slot >= players.size():
		return false
	return players[slot].playing or players[slot].stream_paused


func held_id(slot: int) -> StringName:
	return ids[slot] if slot >= 0 and slot < players.size() and _fade_left[slot] <= 0.0 else &""


func sounding_count() -> int:
	var n: int = 0
	for slot: int in players.size():
		if is_sounding(slot):
			n += 1
	return n


## Freezes the sounding slots in place; false releases them (a pause keeps a held weapon sound where it was).
func set_paused(paused: bool) -> void:
	for p: AudioStreamPlayer in players:
		if paused:
			if p.playing:
				p.stream_paused = true
		else:
			p.stream_paused = false


func _stop(slot: int) -> void:
	var p: AudioStreamPlayer = players[slot]
	p.stop()
	p.stream_paused = false
	p.volume_db = SILENT_DB
	ids[slot] = &""
	_fade_left[slot] = 0.0
