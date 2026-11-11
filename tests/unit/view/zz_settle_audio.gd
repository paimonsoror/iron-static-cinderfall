extends GdUnitTestSuite
## Runs last in tests/unit/view (suites run in alphabetical order). The suites before it fire shot and reload events, the
## `Sfx` autoload answers with one-shot voices, and when the scoped run ends while a voice still plays Godot prints
## "resources still in use at exit", which tools/test.ps1 turns into exit 2 (pristine main shows the same: 5 resources).
## Silencing the voices and giving the audio thread a moment to release them ends the run clean. No view behaviour is tested.


func test_audio_voices_are_released_before_the_run_ends() -> void:
	Sfx.disabled = true  # stops every voice and both beds
	await await_millis(700)
	Sfx.disabled = false
	assert_bool(Sfx.disabled).is_false()
