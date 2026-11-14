extends GdUnitTestSuite
## V4-T: the second weapon of `balanced` (CONTENT 13): swap to the area weapon at 12 enemies in its reach, back at 5. The
## count is taken inside the radius of the area weapon around the Warden (never under the 10 m of CONTENT 13), because 12
## enemies within 10 m of the core is met in about 3 % of the combat ticks of the slice and the arc projector stayed in
## the holster in 6 of 8 seeds. A spent area weapon (venting, reloading) is bridged with the single-target one.
## Hand-made arsenals on TestContent.variety().

var w: SimWorld
var bot: PolicyBot


func before_test() -> void:
	w = VarietyHKit.world()
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 3
	VarietyHKit.carry(w, 0, &"pistol")
	VarietyHKit.carry(w, 1, &"arc_projector")
	w.arsenal.active = 0
	w.tick = 600
	bot = PolicyBot.new(PolicyBot.Policy.BALANCED)


func _swaps() -> Array[int]:
	var out: Array[int] = []
	for c: SimCommand in w.command_queue:
		if c.kind == SimCommand.Kind.SWAP_WEAPON:
			out.append(c.arg)
	return out


func _act() -> Array[int]:
	w.command_queue.clear()
	bot.swap_not_before = 0
	bot.act(w)
	return _swaps()


# --- the radius ---


func test_the_crowd_radius_is_the_reach_of_the_area_weapon_and_never_under_ten_meters() -> void:
	assert_float(PolicyLoadout.crowd_radius(w)).is_equal(18.0)  # the arc projector
	VarietyHKit.carry(w, 1, &"scattergun")
	assert_float(PolicyLoadout.crowd_radius(w)).is_equal(13.0)  # the scattergun's 13 m (V5-C: was 9 m, the floor)
	VarietyHKit.carry(w, 1, &"slag_mortar")
	assert_float(PolicyLoadout.crowd_radius(w)).is_equal(24.0)
	w.arsenal.slot_weapon[1] = -1
	assert_float(PolicyLoadout.crowd_radius(w)).is_equal(PolicyLoadout.CROWD_RADIUS_M)  # no area weapon at all


func test_twelve_enemies_in_reach_of_the_arc_are_a_crowd_although_they_are_far_from_the_core() -> void:
	VarietyHKit.crowd(w, 12, 14.0)  # 14 m from the core, about 12 m from the Warden
	assert_int(PolicySenses.near_core(w, 10.0)).is_equal(0)  # the 10 m of the core would see nobody
	assert_int(PolicyLoadout.crowd_count(w)).is_equal(12)
	assert_array(_act()).is_equal([1])


func test_the_same_crowd_is_not_one_for_a_scattergun() -> void:
	VarietyHKit.carry(w, 1, &"scattergun")
	VarietyHKit.crowd(w, 12, 16.0)
	assert_array(_act()).is_empty()  # about 14 m from the Warden: out of the 13 m of the scattergun
	VarietyHKit.crowd(w, 12, 3.0)
	assert_array(_act()).is_equal([1])


func test_eleven_are_not_a_crowd() -> void:
	VarietyHKit.crowd(w, 11, 14.0)
	assert_array(_act()).is_empty()
	VarietyHKit.crowd(w, 1, 14.0)
	assert_array(_act()).is_equal([1])


func test_the_area_weapon_goes_back_at_five() -> void:
	w.arsenal.active = 1
	VarietyHKit.crowd(w, 6, 14.0)
	assert_array(_act()).is_empty()
	w.enemies.alive[0] = 0  # one fewer: five left
	assert_array(_act()).is_equal([0])


# --- readiness ---


func test_a_hot_arc_is_not_swapped_in_and_a_venting_one_is_bridged() -> void:
	VarietyHKit.crowd(w, 20, 3.0)
	w.arsenal.slot_heat[1] = 80  # above half of the cap: it would vent after a shot or two
	assert_array(_act()).is_empty()
	w.arsenal.slot_heat[1] = 50
	assert_array(_act()).is_equal([1])
	w.arsenal.active = 1
	w.arsenal.slot_vent_left[1] = 150
	assert_array(_act()).is_equal([0])  # fire the pistol while the arc vents
	w.arsenal.slot_vent_left[1] = 30
	assert_array(_act()).is_empty()  # the vent is nearly over: stay


func test_a_spent_area_weapon_is_not_bridged_when_the_other_weapon_is_busy_too() -> void:
	VarietyHKit.crowd(w, 20, 3.0)
	w.arsenal.active = 1
	w.arsenal.slot_vent_left[1] = 150
	w.arsenal.slot_reload_left[0] = 40
	assert_array(_act()).is_empty()


func test_slot_ready_and_spent_read_the_arsenal() -> void:
	assert_bool(PolicyLoadout.slot_ready(w, 0)).is_true()
	assert_bool(PolicyLoadout.slot_ready(w, 2)).is_false()  # no third slot
	w.arsenal.slot_reload_left[0] = 10
	assert_bool(PolicyLoadout.slot_ready(w, 0)).is_false()
	assert_bool(PolicyLoadout.slot_spent(w, 0)).is_false()  # only 10 ticks to go
	w.arsenal.slot_reload_left[0] = 90
	assert_bool(PolicyLoadout.slot_spent(w, 0)).is_true()


func test_one_swap_per_pause_and_none_during_a_swap() -> void:
	VarietyHKit.crowd(w, 14, 3.0)
	assert_array(_act()).is_equal([1])
	w.command_queue.clear()
	w.arsenal.active = 0
	bot.act(w)  # inside the pause the bot has just started
	assert_array(_swaps()).is_empty()
	w.tick += PolicyLoadout.SWAP_PAUSE_TICKS + PolicyLoadout.SCAN_PERIOD
	w.tick -= w.tick % PolicyLoadout.SCAN_PERIOD
	w.arsenal.swap_left = 12
	w.command_queue.clear()
	bot.act(w)
	assert_array(_swaps()).is_empty()  # a swap is still running
