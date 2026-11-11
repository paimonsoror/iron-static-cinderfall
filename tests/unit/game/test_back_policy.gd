extends GdUnitTestSuite
## BackPolicy.decide (ARCH 7.4, GDD 10.2): closes the open drawer or overlay; else pauses during a run; else goes one
## screen back; on the menu it asks to quit.

const A: Dictionary = {
	"OVERLAY": BackPolicy.Action.CLOSE_OVERLAY,
	"DRAWER": BackPolicy.Action.CLOSE_DRAWER,
	"PAUSE": BackPolicy.Action.PAUSE,
	"RESUME": BackPolicy.Action.RESUME,
	"MENU": BackPolicy.Action.TO_MENU,
	"QUIT": BackPolicy.Action.CONFIRM_QUIT,
	"NONE": BackPolicy.Action.NONE,
}


func _d(state: int, drawer: bool, overlay: bool) -> int:
	return BackPolicy.decide(state, drawer, overlay)


func test_the_full_table_with_nothing_open() -> void:
	var expected: Dictionary = {
		GameState.Id.BOOT: "NONE",
		GameState.Id.MENU: "QUIT",
		GameState.Id.BRIEFING: "MENU",
		GameState.Id.PREPARING: "PAUSE",
		GameState.Id.SPAWNING: "PAUSE",
		GameState.Id.CLEARING: "PAUSE",
		GameState.Id.INTERMISSION: "PAUSE",
		GameState.Id.VICTORY: "MENU",
		GameState.Id.DEFEAT: "MENU",
		GameState.Id.PAUSED: "RESUME",
	}
	for state: int in expected:
		var want: int = A[expected[state]]
		assert_int(_d(state, false, false)).is_equal(want)


func test_an_open_drawer_is_closed_first_in_every_run_phase() -> void:
	for state: int in [GameState.Id.PREPARING, GameState.Id.SPAWNING, GameState.Id.CLEARING, GameState.Id.INTERMISSION]:
		assert_int(_d(state, true, false)).is_equal(BackPolicy.Action.CLOSE_DRAWER)


func test_a_drawer_flag_means_nothing_outside_a_run() -> void:
	assert_int(_d(GameState.Id.MENU, true, false)).is_equal(BackPolicy.Action.CONFIRM_QUIT)
	assert_int(_d(GameState.Id.PAUSED, true, false)).is_equal(BackPolicy.Action.RESUME)
	assert_int(_d(GameState.Id.VICTORY, true, false)).is_equal(BackPolicy.Action.TO_MENU)


func test_an_open_overlay_is_closed_before_anything_else() -> void:
	for state: int in GameState.Id.values():
		if state == GameState.Id.BOOT:
			continue
		assert_int(_d(state, false, true)).is_equal(BackPolicy.Action.CLOSE_OVERLAY)
		assert_int(_d(state, true, true)).is_equal(BackPolicy.Action.CLOSE_OVERLAY)


func test_nothing_happens_during_boot() -> void:
	assert_int(_d(GameState.Id.BOOT, false, false)).is_equal(BackPolicy.Action.NONE)
	assert_int(_d(GameState.Id.BOOT, true, true)).is_equal(BackPolicy.Action.NONE)


func test_every_state_and_flag_combination_returns_a_known_action() -> void:
	for state: int in GameState.Id.values():
		for drawer: bool in [false, true]:
			for overlay: bool in [false, true]:
				assert_int(_d(state, drawer, overlay)).is_between(0, BackPolicy.Action.size() - 1)
