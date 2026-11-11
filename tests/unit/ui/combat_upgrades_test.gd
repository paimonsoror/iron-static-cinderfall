extends GdUnitTestSuite
## The upgrade drawer: five cards, one command per tap, reasons, exact cost and level, MAX, affordable count.

var _api: FakeRunApi
var _hud: CombatHud


func before_test() -> void:
	_api = FakeRunApi.new()
	_api.fake_phase = GameState.Id.SPAWNING
	_hud = CombatTestKit.make_hud(self, _api)
	_api.set_scrap(1000)
	_hud.refresh()


func _card(id: StringName) -> HudUpgradeCard:
	return _hud.drawer.cards[id]


func test_drawer_has_exactly_the_five_upgrade_cards() -> void:
	assert_int(_hud.drawer.cards.size()).is_equal(5)
	for id: StringName in Ids.UPGRADES:
		assert_bool(_hud.drawer.cards.has(id)).is_true()
		assert_str(_card(id).name_label.text).is_equal(Strings.t("upgrade.%s.name" % String(id)).to_upper())


func test_tapping_an_affordable_card_issues_one_purchase_with_a_fresh_id() -> void:
	_card(&"damage").pressed.emit()
	var buys: Array[Dictionary] = CombatTestKit.calls_of(_api, "purchase_upgrade")
	assert_int(buys.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)
	var sent_id: StringName = buys[0]["id"]
	var command_id: int = buys[0]["command_id"]
	assert_str(String(sent_id)).is_equal("damage")
	assert_int(command_id).is_greater(0)
	assert_int(_api.next_command_id()).is_greater(command_id)


func test_two_taps_mint_two_different_command_ids() -> void:
	_card(&"damage").pressed.emit()
	_card(&"fire_rate").pressed.emit()
	var buys: Array[Dictionary] = CombatTestKit.calls_of(_api, "purchase_upgrade")
	assert_int(buys.size()).is_equal(2)
	var first: int = buys[0]["command_id"]
	var second: int = buys[1]["command_id"]
	assert_int(second).is_not_equal(first)


func test_a_card_blocked_by_the_api_issues_no_command_and_shows_the_reason() -> void:
	_api.fake_purchase_block[&"damage"] = Reason.Id.INSUFFICIENT_SCRAP
	_hud.refresh()
	assert_bool(_card(&"damage").blocked).is_true()
	_card(&"damage").pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)
	assert_str(_card(&"damage").reason_label.text).is_equal(Strings.t("reason.insufficient_scrap"))
	assert_bool(_card(&"damage").reason_label.visible).is_true()


func test_a_card_the_player_cannot_pay_for_is_blocked_even_if_the_api_says_ok() -> void:
	_api.set_scrap(100)  # the cheapest card costs 150
	_hud.refresh()
	for id: StringName in Ids.UPGRADES:
		_card(id).pressed.emit()
		assert_str(_card(id).reason_label.text).is_equal(Strings.t("reason.insufficient_scrap"))
	assert_int(_api.calls.size()).is_equal(0)


func test_a_locked_card_says_why() -> void:
	_api.fake_purchase_block[&"smg_unlock"] = Reason.Id.PREREQ_NOT_MET
	_hud.refresh()
	_card(&"smg_unlock").pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)
	assert_str(_card(&"smg_unlock").reason_label.text).is_equal(Strings.t("reason.prereq_not_met"))


func test_card_text_shows_the_exact_cost_and_level() -> void:
	_api.fake_upgrade_level[&"damage"] = 2
	_api.fake_upgrade_cost[&"damage"] = 506
	_hud.refresh()
	var card: HudUpgradeCard = _card(&"damage")
	assert_str(card.cost_label.text).is_equal("506")
	assert_str(card.level_label.text).is_equal(Strings.tf("hud.card.level", [2, 5]))
	assert_bool(card.cost_box.visible).is_true()
	assert_bool(card.max_box.visible).is_false()


func test_at_max_level_the_cost_is_hidden_and_max_shows() -> void:
	_api.fake_upgrade_level[&"fire_rate"] = 5
	_api.fake_upgrade_cost[&"fire_rate"] = -1
	_api.fake_purchase_block[&"fire_rate"] = Reason.Id.MAX_LEVEL
	_hud.refresh()
	var card: HudUpgradeCard = _card(&"fire_rate")
	assert_bool(card.is_max).is_true()
	assert_bool(card.cost_box.visible).is_false()
	assert_bool(card.max_box.visible).is_true()
	assert_str(card.max_label.text).is_equal(Strings.t("hud.card.max"))
	card.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_the_effect_line_is_exact_and_comes_from_the_content_numbers() -> void:
	var content: ContentSet = TestContent.baseline()
	var damage: UpgradeDef = content.upgrade(&"damage")
	var expected: String = Strings.tf("hud.effect.damage", [roundi(damage.per_level * 100.0)])
	assert_str(_card(&"damage").effect_label.text).is_equal(expected)
	assert_str(_card(&"auto_turret").effect_label.text).is_equal(Strings.tf("hud.effect.auto_turret", [1, 2]))
	_api.fake_upgrade_level[&"auto_turret"] = 1
	_hud.refresh()
	assert_str(_card(&"auto_turret").effect_label.text).is_equal(Strings.tf("hud.effect.auto_turret", [2, 2]))


func test_the_affordable_count_matches_and_is_on_the_tab() -> void:
	_api.set_scrap(1000)
	_api.fake_purchase_block[&"smg_unlock"] = Reason.Id.PREREQ_NOT_MET
	_api.fake_upgrade_cost[&"auto_turret"] = 1500
	_hud.refresh()
	assert_int(_hud.affordable_count()).is_equal(3)
	assert_str(_hud.bottom.tab_label.text).is_equal(Strings.tf("hud.tab", [3]))
	_api.set_scrap(0)
	assert_int(_hud.affordable_count()).is_equal(0)
	assert_str(_hud.bottom.tab_label.text).is_equal(Strings.tf("hud.tab", [0]))


func test_a_failed_purchase_resolves_into_a_shake_with_the_reason() -> void:
	_api.fake_paused = true
	_card(&"damage").pressed.emit()
	assert_int(_api.calls.size()).is_equal(1)  # the tap was issued; the API refuses it while paused
	assert_str(_card(&"damage").reason_label.text).is_equal(Strings.t("reason.paused"))


func test_there_is_no_weapon_card_strip_and_no_data_counter() -> void:
	_api.fake_phase = GameState.Id.INTERMISSION
	_hud.open_drawer()
	_hud.refresh()
	for l: Label in CombatTestKit.labels(_hud):
		var up: String = l.text.to_upper()
		assert_bool(up.contains("DATA")).is_false()
		assert_bool(up.contains("ASSAULT")).is_false()
		assert_bool(up.contains("LMG")).is_false()
	assert_int(_hud.drawer.cards.size()).is_equal(5)
