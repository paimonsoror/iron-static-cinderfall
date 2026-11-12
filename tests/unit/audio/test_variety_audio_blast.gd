extends GdUnitTestSuite
## AudioBlastMerge: "a big blast sample replaces 4 or more simultaneous small ones" (VARIETY_SPEC 10.5). Pure logic.


func test_nothing_collected_plays_nothing() -> void:
	var merge: AudioBlastMerge = AudioBlastMerge.new()
	assert_array(merge.take()).is_empty()


func test_one_to_three_blasts_stay_small_blasts() -> void:
	var merge: AudioBlastMerge = AudioBlastMerge.new()
	for count: int in range(1, 4):
		for i: int in count:
			merge.add()
		var sounds: Array[StringName] = merge.take()
		assert_int(sounds.size()).is_equal(count)
		for sound: StringName in sounds:
			assert_that(sound).is_equal(&"blast_small")


func test_four_or_more_blasts_become_one_big_blast() -> void:
	var merge: AudioBlastMerge = AudioBlastMerge.new()
	for count: int in [4, 5, 8, 40]:
		for i: int in count:
			merge.add()
		assert_array(merge.take()).is_equal([&"blast_big"])


func test_the_frame_is_forgotten_once_taken_and_clear_forgets_it_too() -> void:
	var merge: AudioBlastMerge = AudioBlastMerge.new()
	for i: int in 6:
		merge.add()
	@warning_ignore("return_value_discarded")
	merge.take()
	assert_int(merge.pending).is_equal(0)
	assert_array(merge.take()).is_empty()
	for i: int in 2:
		merge.add()
	merge.clear()
	assert_array(merge.take()).is_empty()


func test_the_small_blasts_of_a_frame_never_exceed_the_per_id_start_cap() -> void:
	assert_int(AudioBlastMerge.MAX_SMALL).is_equal(AudioVoiceGate.MAX_STARTS_PER_FRAME)
	assert_int(AudioBlastMerge.BIG_AT).is_equal(AudioBlastMerge.MAX_SMALL + 1)  # so a frame is never two sounds' worth
