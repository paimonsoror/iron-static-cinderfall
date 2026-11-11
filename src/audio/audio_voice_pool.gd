class_name AudioVoicePool
extends RefCounted
## A fixed set of AudioStreamPlayer voices. A free voice is used first; when all are busy a new sound takes the
## voice of the lowest priority (oldest first) unless every busy voice outranks it, in which case it is dropped.

var players: Array[AudioStreamPlayer] = []
var ids: Array[StringName] = []  ## what each voice last played

var _priority: PackedInt32Array = PackedInt32Array()
var _started_ms: PackedInt64Array = PackedInt64Array()


## Creates `voice_count` players under `parent` on `bus`.
func build(parent: Node, voice_count: int, bus: StringName) -> void:
	for i: int in voice_count:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = bus
		parent.add_child(p)
		players.append(p)
		ids.append(&"")
		@warning_ignore("return_value_discarded")
		_priority.append(0)
		@warning_ignore("return_value_discarded")
		_started_ms.append(0)


## Index of the voice to use, or -1 when the sound is dropped.
func acquire(priority: int) -> int:
	var victim: int = -1
	for i: int in players.size():
		if not is_busy(i):
			return i
		if victim < 0 or _priority[i] < _priority[victim] \
				or (_priority[i] == _priority[victim] and _started_ms[i] < _started_ms[victim]):
			victim = i
	if victim >= 0 and _priority[victim] <= priority:
		return victim
	return -1


func start(index: int, id: StringName, stream: AudioStream, volume_db: float, pitch: float, priority: int, now_ms: int) -> void:
	var p: AudioStreamPlayer = players[index]
	p.stream_paused = false
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	ids[index] = id
	_priority[index] = priority
	_started_ms[index] = now_ms


## Playing, or frozen by pause_all (Godot reports a paused player as not playing).
func is_busy(index: int) -> bool:
	var p: AudioStreamPlayer = players[index]
	return p.playing or p.stream_paused


func active_count() -> int:
	var n: int = 0
	for i: int in players.size():
		if is_busy(i):
			n += 1
	return n


## Busy voices playing `id`.
func count_of(id: StringName) -> int:
	var n: int = 0
	for i: int in players.size():
		if is_busy(i) and ids[i] == id:
			n += 1
	return n


func stop_all() -> void:
	for p: AudioStreamPlayer in players:
		p.stop()
		p.stream_paused = false


## Freezes the voices that are playing (idle ones stay free for ui sounds); false releases all of them.
func set_paused(paused: bool) -> void:
	for p: AudioStreamPlayer in players:
		if paused:
			if p.playing:
				p.stream_paused = true
		else:
			p.stream_paused = false
