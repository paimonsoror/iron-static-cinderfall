class_name AudioVoicePool
extends RefCounted
## A fixed set of AudioStreamPlayer voices. A free voice is used first; when all are busy a new sound takes the
## voice of the lowest priority (oldest first) unless every busy voice outranks it, in which case it is dropped.
##
## Voice classes (VARIETY_SPEC 10.5; AudioCatalog.CLASS_*), so that a flood of weapon sounds or a chain of blasts cannot
## starve the warning that matters:
##  - ALERT: the last ALERT_RESERVED free voices are kept for alerts (a weapon or blast sound cannot take them), an alert
##    outranks every other class (it may take the voice of any non-alert), and at most ALERT_RESERVED alerts sound at
##    once (a fourth takes the oldest alert);
##  - WEAPON: at most WEAPON_MAX voices; a weapon sound beyond that takes the oldest weapon voice, never another class's;
##  - BLAST: may not take the reserved voices (no count limit of its own; the per-id cap of AudioVoiceGate applies);
##  - OTHER and UI: as before the classes existed (any free voice, or a voice of equal or lower priority).

const ALERT_RESERVED: int = 3
const WEAPON_MAX: int = 8

var players: Array[AudioStreamPlayer] = []
var ids: Array[StringName] = []  ## what each voice last played

var _priority: PackedInt32Array = PackedInt32Array()
var _class: PackedInt32Array = PackedInt32Array()
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
		_class.append(AudioCatalog.CLASS_OTHER)
		@warning_ignore("return_value_discarded")
		_started_ms.append(0)


## The most voices a class may hold at once (0 = no limit of its own).
static func class_cap(voice_class: int) -> int:
	if voice_class == AudioCatalog.CLASS_WEAPON:
		return WEAPON_MAX
	if voice_class == AudioCatalog.CLASS_ALERT:
		return ALERT_RESERVED
	return 0


## Index of the voice to use, or -1 when the sound is dropped. `priority` is the effective priority
## (AudioCatalog.effective_priority).
func acquire(priority: int, voice_class: int = AudioCatalog.CLASS_OTHER) -> int:
	var free: int = -1
	var free_count: int = 0
	var victim: int = -1  ## the busy voice with the lowest priority, oldest first
	var own: int = -1  ## the oldest busy voice of the same class
	var own_count: int = 0
	for i: int in players.size():
		if not is_busy(i):
			free_count += 1
			if free < 0:
				free = i
			continue
		if _class[i] == voice_class:
			own_count += 1
			if own < 0 or _started_ms[i] < _started_ms[own]:
				own = i
		if victim < 0 or _priority[i] < _priority[victim] \
				or (_priority[i] == _priority[victim] and _started_ms[i] < _started_ms[victim]):
			victim = i
	var cap: int = class_cap(voice_class)
	if cap > 0 and own_count >= cap:
		return own if _priority[own] <= priority else -1
	var keeps_reserve: bool = voice_class == AudioCatalog.CLASS_WEAPON or voice_class == AudioCatalog.CLASS_BLAST
	if free >= 0 and (free_count > ALERT_RESERVED or not keeps_reserve):
		return free
	if victim >= 0 and _priority[victim] <= priority:
		return victim
	return -1


func start(index: int, id: StringName, stream: AudioStream, volume_db: float, pitch: float, priority: int, now_ms: int,
		voice_class: int = AudioCatalog.CLASS_OTHER) -> void:
	var p: AudioStreamPlayer = players[index]
	p.stream_paused = false
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	ids[index] = id
	_priority[index] = priority
	_class[index] = voice_class
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


## Busy voices of a class (AudioCatalog.CLASS_*).
func count_of_class(voice_class: int) -> int:
	var n: int = 0
	for i: int in players.size():
		if is_busy(i) and _class[i] == voice_class:
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
