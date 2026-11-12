class_name GameAudioDebug
extends RefCounted
## The sound switches of the debug arguments, for bisecting an audio problem on a device (a phone's audio thread crashed
## where the desktop did not): `--mute`, `--sfx=0|1`, `--music=0|1`, `--loop-trim=<frames>`, `--loop-off`,
## `--audio-trace`. `Game.boot` applies them before `Sfx.apply_settings()`. Every switch is off by default.


static func apply(args: DebugArgs) -> void:
	apply_to(Sfx, args)


## Puts the switches on `director` (the `Sfx` autoload in the game, a fresh director in a test).
static func apply_to(director: AudioDirector, args: DebugArgs) -> void:
	director.force_sound = args.sfx
	director.force_music = args.music
	director.loop_trim = args.loop_trim
	director.loop_off = args.loop_off
	director.trace = args.audio_trace
	director.disabled = args.mute
