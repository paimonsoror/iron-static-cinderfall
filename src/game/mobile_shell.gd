class_name MobileShell
extends Node
## Lifecycle and the back gesture (ARCH 7.4). It only reports; Game decides what to do:
##  - the app went to the background or lost focus (mobile builds only): the profile is flushed at once, then
##    `app_paused` is emitted (Game pauses the run; it stays paused after returning until the player taps RESUME);
##  - the OS back request (Android back button or gesture) emits `back_requested` (Game asks BackPolicy);
##  - on desktop the Escape key (`ui_cancel`) stands in for the back gesture, so the flow can be tried without a phone.

signal app_paused
signal back_requested

## React to the app leaving the foreground. True on mobile builds only (a desktop window that loses focus must not
## pause a run); tests switch it on to send the real notifications.
var lifecycle_enabled: bool = OS.has_feature("mobile")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if lifecycle_enabled:
				on_app_paused()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()


## The app is leaving the foreground: write the profile, then tell Game to pause.
func on_app_paused() -> void:
	GameRewards.flush_now()
	app_paused.emit()
