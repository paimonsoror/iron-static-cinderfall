extends GdUnitTestSuite
## W2-E: the HUD sandbox cycles the states a review needs and stays capturable (a Control that fills its viewport).


func _sandbox() -> HudSandbox:
	var packed: PackedScene = load("res://src/debug/hud_sandbox.tscn") as PackedScene
	var made: Node = packed.instantiate()
	var node: HudSandbox = made as HudSandbox
	var host: Control = Control.new()
	auto_free(host)
	host.size = Vector2(1080.0, 1920.0)
	add_child(host)
	host.add_child(node)
	return node


func test_every_state_applies_without_errors_and_changes_the_hud() -> void:
	var sb: HudSandbox = _sandbox()
	var hud: CombatHud = sb.hud()
	var api: FakeRunApi = sb.api()
	assert_int(api.scrap()).is_equal(120)
	assert_bool(hud.is_drawer_open()).is_false()
	sb.apply_step(1)
	assert_bool(hud.is_drawer_open()).is_true()
	assert_int(api.upgrade_cost(&"fire_rate")).is_equal(-1)  # a maxed card
	assert_int(api.purchase_block_reason(&"smg_unlock")).is_equal(Reason.Id.PREREQ_NOT_MET)  # a locked card
	assert_int(api.purchase_block_reason(&"armor_piercing")).is_equal(Reason.Id.INSUFFICIENT_SCRAP)  # too expensive
	sb.apply_step(2)
	assert_bool(hud.is_drawer_open()).is_false()
	assert_int(api.ability_active_left(&"shield")).is_greater(0)
	assert_int(api.ability_cooldown_left(&"emp")).is_greater(0)
	assert_float(api.shield_hp()).is_greater(0.0)
	sb.apply_step(3)
	assert_float(api.boss_hp()).is_greater(0.0)
	assert_float(api.core_hp() / api.core_max_hp()).is_less(0.15)
	assert_int(api.wave()).is_equal(5)
	sb.apply_step(4)
	assert_int(api.magazine()).is_equal(0)
	assert_int(api.reload_ticks_left()).is_greater(0)
	sb.apply_step(5)
	assert_int(api.phase()).is_equal(GameState.Id.INTERMISSION)
	assert_int(api.phase_ticks_left()).is_greater(0)


func test_the_cycle_advances_by_itself_and_wraps_to_a_clean_state() -> void:
	var sb: HudSandbox = _sandbox()
	var api: FakeRunApi = sb.api()
	var steps_seen: Array[int] = []
	for _n: int in 6:
		sb._process(2.6)
		steps_seen.append(sb.current_step())
	assert_array(steps_seen).contains_exactly([1, 2, 3, 4, 5, 0])
	# the new lap starts clean: no boss, no shield, nothing cooling, magazine full, combat phase
	assert_float(api.boss_hp()).is_less(0.0)
	assert_float(api.shield_hp()).is_equal(0.0)
	assert_int(api.ability_cooldown_left(&"emp")).is_equal(0)
	assert_int(api.magazine()).is_equal(api.magazine_size())
	assert_int(api.phase()).is_equal(GameState.Id.SPAWNING)
	assert_int(api.upgrade_level(&"damage")).is_equal(0)


func test_timers_count_down_while_cycling() -> void:
	var sb: HudSandbox = _sandbox()
	var api: FakeRunApi = sb.api()
	sb.apply_step(2)
	var before: int = api.ability_cooldown_left(&"emp")
	sb._process(0.5)  # 30 ticks
	assert_int(api.ability_cooldown_left(&"emp")).is_less(before)


func test_the_sandbox_fills_its_viewport_so_a_capture_shows_the_whole_hud() -> void:
	var sb: HudSandbox = _sandbox()
	assert_float(sb.anchor_right).is_equal(1.0)
	assert_float(sb.anchor_bottom).is_equal(1.0)
	assert_bool(sb.theme != null).is_true()
