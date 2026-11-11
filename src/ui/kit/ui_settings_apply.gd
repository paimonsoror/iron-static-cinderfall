class_name UiSettingsApply
extends RefCounted
## Puts a changed setting to work at once, for the effects the UI layer can reach. The value itself is stored by
## Save.set_setting, which also emits Events.settings_changed for everyone else (the view applies Quality and
## High Contrast to the battlefield, the audio director reads Sound and Music).
##   fps_cap        -> Engine.max_fps
##   sound_on, music_on -> Sfx.apply_settings()
##   high_contrast  -> UiScreenFrame re-skins itself on the signal; nothing global to do here
## Call apply_all() once at boot so a saved choice is in force before the first frame.


static func apply(key: StringName) -> void:
	match key:
		&"fps_cap":
			var v: Variant = Save.get_setting(&"fps_cap")
			if typeof(v) == TYPE_INT:
				var cap: int = v
				Engine.max_fps = cap
		&"sound_on", &"music_on":
			Sfx.apply_settings()


static func apply_all() -> void:
	for key: StringName in [&"fps_cap", &"sound_on", &"music_on"]:
		apply(key)
