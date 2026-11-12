extends GdUnitTestSuite
## Runs last in tests/unit/game (suites run in alphabetical order). The suites before it start runs through the real
## `Events` bus, the `Sfx` autoload answers with its beds (ambience, the combat drone) and one-shot voices, and a run
## that is killed for a resume test never ends them. When the scoped run ends while a bed still plays Godot prints
## "resources still in use at exit", which tools/test.ps1 turns into exit 2 (the same reason as
## tests/unit/view/zz_settle_audio.gd). Silencing the voices and giving the audio thread a moment to release them ends
## the run clean. No game behaviour is tested.


func test_audio_voices_are_released_before_the_run_ends() -> void:
	Sfx.disabled = true  # stops every voice and both beds
	await await_millis(700)
	Sfx.disabled = false
	assert_bool(Sfx.disabled).is_false()
