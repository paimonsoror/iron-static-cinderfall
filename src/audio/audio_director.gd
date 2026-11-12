class_name AudioDirector
extends Node
## `Sfx` autoload (ARCH 10). Plays the generated sounds from a 16-voice pool and runs the two loop beds.
##  - `play(id)`: per id at most 3 starts per frame and a minimum interval (AudioVoiceGate); small pitch jitter from
##    this node's own RandomNumberGenerator (never the sim's); when all voices are busy a sound takes the voice of an
##    equal or lower priority (AudioVoicePool).
##  - An internal AudioEventRouter turns `Events` signals into sounds; UI code calls `Sfx.play(&"ui_tap")` directly.
##  - `pause_all` / `resume_all` freeze and release every voice and bed; while paused only `ui_*` sounds start.
##  - Settings `sound_on` / `music_on` come from `Save` and apply at once (`Events.settings_changed`); `disabled` is
##    the `--mute` switch (Game sets it at boot).
## Read-only with respect to the simulation: it listens to `Events` and nothing else.

const VOICES: int = 16
const RECENT_MAX: int = 32
const LOOP_FADE_SECONDS: float = 0.8  ## beds fade in and out over this long
const INTENSITY_SECONDS: float = 1.5  ## time for the drone level to follow a new intensity
const AMBIENCE_DB: float = -12.0
const DRONE_DB_MIN: float = -34.0  ## drone volume at intensity 0+ ...
const DRONE_DB_MAX: float = -9.0  ## ... and at intensity 1
const SILENT_DB: float = -80.0

## `--mute`. Setting it stops everything that is playing.
var disabled: bool = false:
	set(value):
		disabled = value
		if disabled:
			_silence()

var sound_on: bool = true  ## Save setting: sound effects
var music_on: bool = true  ## Save setting: the two loop beds
var auto_route: bool = true  ## false: do not create the Events router in _ready (tests)
var gate: AudioVoiceGate = AudioVoiceGate.new()
var pool: AudioVoicePool = AudioVoicePool.new()
var router: AudioEventRouter = null
var loop_ambience: AudioStreamPlayer = null
var loop_drone: AudioStreamPlayer = null
var started_total: int = 0  ## voices started since creation
var recent_ids: Array[StringName] = []  ## the last RECENT_MAX started ids, oldest first
var last_pitch: float = 1.0  ## pitch_scale of the last started voice
var warn_count: int = 0  ## warnings logged (unknown id, missing file), each at most once per id
## Debug switches for bisecting an audio problem on a device (GameAudioDebug sets them from the debug arguments).
var trace: bool = false  ## log every started sound and bed start
var force_sound: int = -1  ## 0 or 1 overrides the saved `sound_on` (-1 = the saved setting)
var force_music: int = -1  ## 0 or 1 overrides the saved `music_on`
var loop_trim: int = 0  ## frames pulled off the loop end of the two beds when they start
var loop_off: bool = false  ## the beds play once instead of looping

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _streams: Dictionary[StringName, AudioStream] = {}
var _warned: Dictionary[StringName, bool] = {}
var _paused: bool = false
var _ambience_wanted: bool = false
var _amb_gain: float = 0.0  ## 0..1, follows the wanted state over LOOP_FADE_SECONDS
var _intensity: float = 0.0  ## wanted drone level
var _drone_level: float = 0.0  ## current drone level (smoothed)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	AudioMix.ensure_buses()
	pool.build(self, VOICES, AudioMix.BUS_SFX)
	loop_ambience = _make_loop_player()
	loop_drone = _make_loop_player()
	for id: StringName in AudioCatalog.IDS:
		@warning_ignore("return_value_discarded")
		_stream_for(id)
	@warning_ignore("return_value_discarded")
	Events.settings_changed.connect(_on_settings_changed)
	apply_settings()
	if auto_route:
		router = AudioEventRouter.new()
		router.bind(Events, self)
	Log.info("Sfx", "audio ready voices=%d sounds=%d" % [VOICES, _streams.size()])


func _exit_tree() -> void:
	if Events.settings_changed.is_connected(_on_settings_changed):
		Events.settings_changed.disconnect(_on_settings_changed)
	if router != null:
		router.unbind()
	_silence()
	_streams.clear()


func _process(delta: float) -> void:
	advance(delta)


## One frame of the time-based parts (bed fades, drone level, router timers). Frozen while paused or disabled.
func advance(dt: float) -> void:
	if _paused or disabled:
		return
	var target: float = 1.0 if _bed_allowed() and _ambience_wanted else 0.0
	var gain_before: float = _amb_gain
	var level_before: float = _drone_level
	_amb_gain = move_toward(_amb_gain, target, dt / LOOP_FADE_SECONDS)
	_drone_level = move_toward(_drone_level, _intensity, dt / INTENSITY_SECONDS)
	if _amb_gain != gain_before or _drone_level != level_before:
		_apply_loop_volumes()
	if target == 0.0 and _amb_gain <= 0.0 and (loop_ambience.playing or loop_drone.playing):
		_stop_loops()
	if router != null:
		router.advance(dt)


# --- effects --------------------------------------------------------------------------------------------------

## Pooled, voice-capped, with a little pitch jitter. An unknown id logs once and is ignored.
func play(id: StringName) -> void:
	@warning_ignore("return_value_discarded")
	try_play(id)


## `play` that says whether a voice started.
func try_play(id: StringName) -> bool:
	if disabled or not sound_on:
		return false
	if not AudioCatalog.has_sound(id):
		_warn_once(id, "unknown sound id '%s'" % String(id))
		return false
	if _paused and not AudioCatalog.is_ui(id):
		return false
	var now: int = Time.get_ticks_msec()
	if not gate.try_start(id, Engine.get_process_frames(), now, AudioCatalog.min_interval_ms(id)):
		return false
	var stream: AudioStream = _stream_for(id)
	if stream == null:
		return false
	var priority: int = AudioCatalog.priority(id)
	var voice: int = pool.acquire(priority)
	if voice < 0:
		return false
	var jitter: float = AudioCatalog.pitch_jitter(id)
	last_pitch = 1.0 + jitter * _rng.randf_range(-1.0, 1.0)
	pool.start(voice, id, stream, AudioCatalog.volume_db(id), last_pitch, priority, now)
	if trace:
		Log.info("Sfx", "t=%d play %s voice=%d pitch=%.3f" % [now, String(id), voice, last_pitch])
	started_total += 1
	recent_ids.append(id)
	if recent_ids.size() > RECENT_MAX:
		recent_ids.pop_front()
	return true


## Makes the pitch jitter reproducible (tests).
func seed_rng(value: int) -> void:
	_rng.seed = value


# --- beds -----------------------------------------------------------------------------------------------------

## Rain, hum and far metal fade in; the combat drone starts with the level set by `set_intensity`.
func start_ambience() -> void:
	_ambience_wanted = true
	if disabled or not _bed_allowed():
		return
	_start_loops()


## The beds fade out (LOOP_FADE_SECONDS) and stop.
func stop_ambience() -> void:
	_ambience_wanted = false


func is_ambience_wanted() -> bool:
	return _ambience_wanted


## 0..1, the combat drone layer's level (clamped). Waves raise it; the intermission drops it.
func set_intensity(level: float) -> void:
	_intensity = clampf(level, 0.0, 1.0)


func intensity() -> float:
	return _intensity


## Current drone level after smoothing (0..1).
func drone_level() -> float:
	return _drone_level


# --- pause and settings -------------------------------------------------------------------------------------

## Freezes every voice and bed in place and stops the timers. While paused only ui_* sounds start.
func pause_all() -> void:
	_paused = true
	pool.set_paused(true)
	for p: AudioStreamPlayer in [loop_ambience, loop_drone]:
		if p.playing:
			p.stream_paused = true  # Godot reports a paused player as not playing


func resume_all() -> void:
	_paused = false
	pool.set_paused(false)
	for p: AudioStreamPlayer in [loop_ambience, loop_drone]:
		p.stream_paused = false
	if _ambience_wanted and _bed_allowed():
		_start_loops()  # a bed requested during the pause starts now


func is_paused() -> bool:
	return _paused


## Reads `sound_on` and `music_on` from Save. Turning one off silences it at once.
func apply_settings() -> void:
	sound_on = _setting(&"sound_on")
	music_on = _setting(&"music_on")
	if not sound_on:
		pool.stop_all()
	if not music_on:
		_amb_gain = 0.0
		_stop_loops()
	elif _ambience_wanted and not disabled:
		_start_loops()


func _setting(key: StringName) -> bool:
	if key == &"sound_on" and force_sound >= 0:
		return force_sound == 1
	if key == &"music_on" and force_music >= 0:
		return force_music == 1
	var value: Variant = Save.get_setting(key)
	if typeof(value) != TYPE_BOOL:
		return true  # missing or odd value: stay audible
	var on: bool = value
	return on


func _on_settings_changed(key: StringName) -> void:
	if key == &"sound_on" or key == &"music_on":
		apply_settings()


# --- internals ------------------------------------------------------------------------------------------------

func _bed_allowed() -> bool:
	return music_on and not disabled


func _make_loop_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = AudioMix.BUS_MUSIC
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _start_loops() -> void:
	if loop_ambience.stream == null:
		loop_ambience.stream = load(AudioCatalog.LOOP_AMBIENCE) as AudioStream
	if loop_drone.stream == null:
		loop_drone.stream = load(AudioCatalog.LOOP_DRONE) as AudioStream
	_tune_loop(loop_ambience.stream)
	_tune_loop(loop_drone.stream)
	if _paused:
		return  # resume_all starts them
	for p: AudioStreamPlayer in [loop_ambience, loop_drone]:
		if p.stream != null and not p.playing and not p.stream_paused:
			p.play()
			if trace:
				Log.info("Sfx", "t=%d bed start %s" % [Time.get_ticks_msec(), p.stream.resource_path])
	_apply_loop_volumes()


## Device-debug tuning of a bed's loop points (`loop_trim`, `loop_off`); does nothing by default. The stream is a shared
## cached resource, so it is tuned once (a meta flag marks it).
func _tune_loop(stream: AudioStream) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav == null or (loop_trim <= 0 and not loop_off) or wav.has_meta(&"loop_tuned"):
		return
	wav.set_meta(&"loop_tuned", true)
	if loop_off:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	else:
		wav.loop_end = maxi(wav.loop_begin + 1, wav.loop_end - loop_trim)


func _stop_loops() -> void:
	for p: AudioStreamPlayer in [loop_ambience, loop_drone]:
		if p != null:
			p.stop()
			p.stream_paused = false


func _apply_loop_volumes() -> void:
	var fade_db: float = linear_to_db(maxf(_amb_gain, 0.0001))
	loop_ambience.volume_db = maxf(AMBIENCE_DB + fade_db, SILENT_DB)
	if _drone_level <= 0.001:
		loop_drone.volume_db = SILENT_DB
	else:
		loop_drone.volume_db = maxf(lerpf(DRONE_DB_MIN, DRONE_DB_MAX, _drone_level) + fade_db, SILENT_DB)


## --mute: everything stops and nothing restarts.
func _silence() -> void:
	if pool.players.is_empty():
		return
	pool.stop_all()
	_amb_gain = 0.0
	_stop_loops()


func _stream_for(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var stream: AudioStream = AudioCatalog.load_sfx(id)
	if stream == null:
		_warn_once(id, "no stream for '%s' (%s)" % [String(id), AudioCatalog.sfx_path(id)])
		return null
	_streams[id] = stream
	return stream


func _warn_once(id: StringName, message: String) -> void:
	if _warned.has(id):
		return
	_warned[id] = true
	warn_count += 1
	Log.warn("Sfx", message)
