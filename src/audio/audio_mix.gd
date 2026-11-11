class_name AudioMix
extends RefCounted
## Runtime audio buses (the project has no bus layout file): "Sfx" with a limiter, so 16 loud voices cannot clip the
## output, and "Music" for the two loop beds. Both send to Master.

const BUS_SFX: StringName = &"Sfx"
const BUS_MUSIC: StringName = &"Music"


## Idempotent: several directors (tests) may call it.
static func ensure_buses() -> void:
	_ensure(BUS_SFX, true)
	_ensure(BUS_MUSIC, false)


static func _ensure(bus: StringName, limiter: bool) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")
	if limiter:
		var lim: AudioEffectLimiter = AudioEffectLimiter.new()
		lim.ceiling_db = -1.0
		lim.threshold_db = -4.0
		AudioServer.add_bus_effect(index, lim)
