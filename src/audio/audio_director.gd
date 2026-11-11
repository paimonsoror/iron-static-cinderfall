extends Node
## `Sfx` autoload (ARCH 10). Wave 0 stub: every call is a no-op. TODO(W2-C).
## UI code calls Sfx.play(&"ui_tap") directly; gameplay sounds come from an internal router on Events.

@warning_ignore_start("unused_parameter")

var disabled: bool = false  ## --mute


func play(id: StringName) -> void:
	# TODO(W2-C)
	pass


func start_ambience() -> void:
	# TODO(W2-C)
	pass


func stop_ambience() -> void:
	# TODO(W2-C)
	pass


## 0..1, combat drone layer.
func set_intensity(level: float) -> void:
	# TODO(W2-C)
	pass


func pause_all() -> void:
	# TODO(W2-C)
	pass


func resume_all() -> void:
	# TODO(W2-C)
	pass


## Reads sound_on / music_on from Save.
func apply_settings() -> void:
	# TODO(W2-C)
	pass
