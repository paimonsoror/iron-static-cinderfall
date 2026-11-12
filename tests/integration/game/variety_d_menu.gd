class_name VarietyDMenu
extends MainMenuScreen
## Test helper (V2-D): a main menu that already has the RESUME RUN contract GameRunFlow looks for (the real button is
## added by the UI task): the signal `resume_pressed` and the method `set_resume_wave(wave)`.

@warning_ignore("unused_signal")
signal resume_pressed

var resume_wave: int = -1  ## what Game told the menu; -1 = never told


func set_resume_wave(wave: int) -> void:
	resume_wave = wave
