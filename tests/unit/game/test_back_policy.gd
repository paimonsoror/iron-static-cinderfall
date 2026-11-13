extends GdUnitTestSuite
## BackPolicy.decide (ARCH 7.4, GDD 10.2): closes the open overlay; else pauses during a run; else goes one screen back;
## on the menu it asks to quit. (The upgrade drawer and its CLOSE_DRAWER action are gone since V5-A.)

const A: Dictionary = {
	"OVERLAY": BackPolicy.Action.CLOSE_OVERLAY,
	"PAUSE": BackPolicy.Action.PAUSE,
	"RESUME": BackPolicy.Action.RESUME,
	"MENU": BackPolicy.Action.TO_MENU,
	"QUIT": BackPolicy.Action.CONFIRM_QUIT,
	"NONE": BackPolicy.Action.NONE,
}


func _d(state: int, overlay: bool) -> int:
	return BackPolicy.decide(state, overlay)


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
		assert_int(_d(state, false)).is_equal(want)


func test_the_drawer_action_is_gone() -> void:
	assert_bool(BackPolicy.Action.keys().has("CLOSE_DRAWER")).is_false()
	assert_int(BackPolicy.Action.size()).is_equal(A.size())


func test_an_open_overlay_is_closed_before_anything_else() -> void:
	for state: int in GameState.Id.values():
		if state == GameState.Id.BOOT:
			continue
		assert_int(_d(state, true)).is_equal(BackPolicy.Action.CLOSE_OVERLAY)


func test_nothing_happens_during_boot() -> void:
	assert_int(_d(GameState.Id.BOOT, false)).is_equal(BackPolicy.Action.NONE)
	assert_int(_d(GameState.Id.BOOT, true)).is_equal(BackPolicy.Action.NONE)


func test_every_state_and_flag_combination_returns_a_known_action() -> void:
	for state: int in GameState.Id.values():
		for overlay: bool in [false, true]:
			assert_int(_d(state, overlay)).is_between(0, BackPolicy.Action.size() - 1)
