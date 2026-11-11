extends GdUnitTestSuite
## AudioVoiceGate: at most 3 starts of one id per frame and a minimum interval between starts of one id.

var _gate: AudioVoiceGate


func before_test() -> void:
	_gate = AudioVoiceGate.new()


func test_the_fourth_start_of_an_id_in_one_frame_is_refused() -> void:
	_gate.intervals_enabled = false
	var granted: int = 0
	for i: int in 100:
		if _gate.try_start(&"shot_smg", 7, 1000, 0):
			granted += 1
	assert_int(granted).is_equal(AudioVoiceGate.MAX_STARTS_PER_FRAME)
	assert_int(granted).is_equal(3)


func test_a_new_frame_resets_the_count() -> void:
	_gate.intervals_enabled = false
	for i: int in 5:
		@warning_ignore("return_value_discarded")
		_gate.try_start(&"shot_smg", 7, 1000, 0)
	assert_bool(_gate.try_start(&"shot_smg", 8, 1016, 0)).is_true()


func test_ids_are_counted_separately() -> void:
	_gate.intervals_enabled = false
	for i: int in 3:
		assert_bool(_gate.try_start(&"shot_smg", 1, 0, 0)).is_true()
	assert_bool(_gate.try_start(&"shot_smg", 1, 0, 0)).is_false()
	assert_bool(_gate.try_start(&"hit_armor", 1, 0, 0)).is_true()


func test_the_minimum_interval_blocks_an_early_restart_and_allows_a_late_one() -> void:
	assert_bool(_gate.try_start(&"shot_pistol", 1, 1000, 90)).is_true()
	assert_bool(_gate.try_start(&"shot_pistol", 2, 1089, 90)).is_false()
	assert_bool(_gate.try_start(&"shot_pistol", 3, 1090, 90)).is_true()


func test_a_refused_start_does_not_push_the_interval_back() -> void:
	assert_bool(_gate.try_start(&"shot_pistol", 1, 1000, 90)).is_true()
	assert_bool(_gate.try_start(&"shot_pistol", 2, 1050, 90)).is_false()
	assert_bool(_gate.try_start(&"shot_pistol", 3, 1091, 90)).is_true()


func test_clear_forgets_everything() -> void:
	assert_bool(_gate.try_start(&"shot_pistol", 1, 1000, 5000)).is_true()
	_gate.clear()
	assert_bool(_gate.try_start(&"shot_pistol", 1, 1001, 5000)).is_true()
