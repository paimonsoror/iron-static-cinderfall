class_name Haptics
extends RefCounted
## Vibration (GDD A20: short ticks on purchase, core hit and boss spawn; needs only the VIBRATE permission).
## A no-op unless the platform is Android and the `haptics_on` setting is on.


static func tick(ms: int = 20) -> void:
	if not enabled():
		return
	Input.vibrate_handheld(clampi(ms, 1, 500))


## True on Android with the haptics setting on.
static func enabled() -> bool:
	if not OS.has_feature("android"):
		return false
	return Save.get_setting(&"haptics_on") == true
