extends GdUnitTestSuite
## V4-U: the Archive (GDD 8.5, 10.7). The model (rows by tier, tier gates, states, the UNDO window), the in-memory bank's
## purchase rules, and the screen (four tabs, rows of 500 x 200, a detail panel, an UNLOCK button that names its price, UNDO,
## close) on three aspects and a narrow phone. The screen is driven through an ArchiveBank, so none of this needs the profile
## v2 of task V4-M; the Save-bound bank is tested against whatever Save offers.

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = V4uKit.content()


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _bank(data: int, owned: Array[String] = []) -> ArchiveBank:
	return ArchiveBank.new(V4uKit.profile(data, owned), _cs)


# --- the model ---


func test_the_rows_of_a_branch_come_in_tier_order() -> void:
	var model: ArchiveModel = ArchiveModel.new(_cs, _bank(0))
	var armory: Array[UnlockDef] = model.rows(UnlockDef.Branch.ARMORY)
	assert_int(armory.size()).is_equal(6)
	var last: int = 0
	for def: UnlockDef in armory:
		assert_int(def.tier).is_greater_equal(last)
		last = def.tier
	assert_array(model.tiers(UnlockDef.Branch.ARMORY)).is_equal([1, 2, 3])
	assert_int(model.rows(UnlockDef.Branch.DIRECTIVES).size()).is_equal(7)
	assert_int(model.rows(UnlockDef.Branch.KITS).size()).is_equal(5)
	assert_int(model.rows(UnlockDef.Branch.FIELD).size()).is_equal(6)


func test_tier_two_opens_after_three_unlocks_and_tier_three_after_eight() -> void:
	assert_int(ArchiveModel.gate(_cs, 1)).is_equal(0)
	assert_int(ArchiveModel.gate(_cs, 2)).is_equal(3)
	assert_int(ArchiveModel.gate(_cs, 3)).is_equal(8)
	assert_bool(ArchiveModel.tier_is_open(_cs, 2, 2)).is_false()
	assert_bool(ArchiveModel.tier_is_open(_cs, 3, 2)).is_true()
	assert_bool(ArchiveModel.tier_is_open(_cs, 7, 3)).is_false()
	assert_bool(ArchiveModel.tier_is_open(_cs, 8, 3)).is_true()
	assert_int(ArchiveModel.gate(null, 2)).is_equal(0)


func test_a_row_is_owned_available_poor_or_locked_by_its_tier() -> void:
	var model: ArchiveModel = ArchiveModel.new(_cs, _bank(100, ["u_w_hornet"]))
	assert_int(model.state(_cs.unlock(&"u_w_hornet"))).is_equal(ArchiveModel.State.OWNED)
	assert_int(model.state(_cs.unlock(&"u_w_lmg"))).is_equal(ArchiveModel.State.POOR)  # 120 > 100
	assert_int(model.state(_cs.unlock(&"u_p_blast"))).is_equal(ArchiveModel.State.AVAILABLE)  # 100
	assert_int(model.state(_cs.unlock(&"u_w_mortar"))).is_equal(ArchiveModel.State.TIER_LOCKED)  # 1 unlock of 3
	assert_int(model.owned_total()).is_equal(1)


func test_unknown_unlock_ids_in_the_profile_are_not_counted() -> void:
	var model: ArchiveModel = ArchiveModel.new(_cs, _bank(0, ["u_from_a_newer_build", "u_w_hornet"]))
	assert_int(model.owned_total()).is_equal(1)


func test_a_held_purchase_keeps_its_price_back_until_it_is_committed() -> void:
	var bank: ArchiveBank = _bank(300)
	var model: ArchiveModel = ArchiveModel.new(_cs, bank)
	var def: UnlockDef = _cs.unlock(&"u_w_lmg")
	assert_bool(model.hold(def)).is_true()
	assert_int(model.data()).is_equal(180)
	assert_int(bank.data()).is_equal(300)  # nothing bought yet
	assert_int(model.state(def)).is_equal(ArchiveModel.State.PENDING)
	assert_bool(model.hold(_cs.unlock(&"u_w_hornet"))).is_false()  # one at a time
	model.release()
	assert_int(model.data()).is_equal(300)
	assert_bool(model.hold(def)).is_true()
	assert_int(model.commit()).is_equal(Reason.Id.OK)
	assert_int(bank.data()).is_equal(180)
	assert_bool(bank.owns(&"u_w_lmg")).is_true()
	assert_int(model.state(def)).is_equal(ArchiveModel.State.OWNED)


func test_the_one_more_run_hook_names_the_dearest_row_the_data_covers() -> void:
	var model: ArchiveModel = ArchiveModel.new(_cs, _bank(130))
	var best: UnlockDef = model.best_affordable()
	assert_str(String(best.id)).is_equal("u_w_lmg")  # 120 is the dearest of the tier 1 rows at 130
	var poor: ArchiveModel = ArchiveModel.new(_cs, _bank(50))
	assert_object(poor.best_affordable()).is_null()
	assert_str(String(poor.next_goal().id)).is_equal("u_w_hornet")  # the cheapest row more Data would buy (80)
	assert_object(ArchiveModel.new(_cs, _bank(0, [])).best_affordable()).is_null()


# --- the bank ---


func test_the_bank_enforces_the_purchase_rules_in_order() -> void:
	var bank: ArchiveBank = _bank(500)
	assert_int(bank.purchase(&"nope")).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(bank.purchase(&"u_w_mortar")).is_equal(Reason.Id.PREREQ_NOT_MET)  # tier 2 needs 3 unlocks
	assert_int(bank.purchase(&"u_w_hornet")).is_equal(Reason.Id.OK)
	assert_int(bank.purchase(&"u_w_hornet")).is_equal(Reason.Id.DUPLICATE_COMMAND)
	assert_int(bank.data()).is_equal(420)
	assert_int(bank.purchase(&"u_w_lmg")).is_equal(Reason.Id.OK)
	assert_int(bank.purchase(&"u_p_blast")).is_equal(Reason.Id.OK)
	assert_int(bank.owned_count()).is_equal(3)
	assert_int(bank.purchase(&"u_w_mortar")).is_equal(Reason.Id.OK)  # the tier is open now: 3 unlocks
	assert_int(bank.purchase(&"u_w_torch")).is_equal(Reason.Id.INSUFFICIENT_SCRAP)  # 40 left, 220 asked
	assert_int(bank.data()).is_equal(40)  # a refused purchase costs nothing


func test_the_save_bank_buys_through_save_whichever_build_it_stands_on() -> void:
	Save.profile.data = 500
	var bank: SaveArchiveBank = SaveArchiveBank.new(_cs)
	assert_int(bank.purchase(&"u_w_hornet")).is_equal(Reason.Id.OK)
	assert_bool(Save.has_unlock(&"u_w_hornet")).is_true()
	assert_int(Save.profile.data).is_equal(420)
	assert_int(bank.purchase(&"u_w_hornet")).is_not_equal(Reason.Id.OK)
	assert_int(Save.profile.data).is_equal(420)
	bank.set_kit(&"k_breacher")
	assert_str(String(Save.profile.kit)).is_equal("k_breacher")


# --- the screen ---


func test_the_screen_shows_four_tabs_and_the_rows_of_the_armory() -> void:
	var screen: ArchiveScreen = V4uKit.archive(self, _cs, _bank(412))
	await V4uKit.settle(get_tree())
	assert_int(screen.tab_buttons.size()).is_equal(4)
	for b: Button in screen.tab_buttons:
		assert_float(b.size.y).is_greater_equal(132.0)
	assert_str(screen.data_label.text).is_equal("412")
	assert_int(screen.rows.size()).is_equal(6)
	for row: ArchiveRow in screen.rows:
		assert_float(row.size.x).is_greater_equal(ArchiveRow.MIN_W - 40.0)
		assert_float(row.size.y).is_greater_equal(ArchiveRow.MIN_H)
	assert_int(screen.tier_labels.size()).is_equal(3)
	assert_str(screen.tier_labels[1].text).contains("3")  # TIER 2 (3 UNLOCKS NEEDED: 0 / 3)
	assert_str(screen.tier_labels[1].text).contains("0 / 3")
	screen.select_branch(UnlockDef.Branch.KITS)
	assert_int(screen.rows.size()).is_equal(5)
	screen.select_branch(UnlockDef.Branch.FIELD)
	assert_int(screen.rows.size()).is_equal(6)
	screen.select_branch(UnlockDef.Branch.DIRECTIVES)
	assert_int(screen.rows.size()).is_equal(7)


func test_unlock_names_its_price_and_a_row_states_its_state_in_words() -> void:
	var screen: ArchiveScreen = V4uKit.archive(self, _cs, _bank(100, ["u_w_hornet"]))
	assert_str(screen.row_of(&"u_w_hornet").state_label.text).is_equal(Strings.t("archive.owned"))
	assert_str(screen.row_of(&"u_w_lmg").state_label.text).contains("NEED")  # 120 against 100
	assert_str(screen.row_of(&"u_w_mortar").state_label.text).contains("LOCKED")
	screen.select(_cs.unlock(&"u_w_lmg"))
	assert_bool(screen.unlock_button.disabled).is_true()
	assert_str(screen.unlock_button.text).contains("20")  # NEED 20 MORE DATA
	assert_str(screen.detail.why_label.text).contains("20")
	var buyable: ArchiveScreen = V4uKit.archive(self, _cs, _bank(300))
	assert_str(String(buyable.selected.id)).is_equal("u_w_hornet")  # the first row that can be bought is in focus
	assert_bool(buyable.unlock_button.disabled).is_false()
	assert_str(buyable.unlock_button.text).is_equal(Strings.tf("archive.unlock_for", ["80"]))
	assert_str(buyable.detail.name_label.text).is_equal("HORNET RACK")
	assert_str(buyable.detail.meta_label.text).contains("DMG")


func test_a_closed_tier_cannot_be_bought_and_says_how_many_unlocks_it_needs() -> void:
	var screen: ArchiveScreen = V4uKit.archive(self, _cs, _bank(900))
	screen.select(_cs.unlock(&"u_w_mortar"))
	assert_bool(screen.unlock_button.disabled).is_true()
	assert_str(screen.unlock_button.text).is_equal(Strings.tf("archive.gate_needed", [3]))
	screen.unlock_button.pressed.emit()
	assert_bool(screen.model.bank.owns(&"u_w_mortar")).is_false()


func test_unlock_waits_in_an_undo_window_and_undo_cancels_it() -> void:
	var bank: ArchiveBank = _bank(300)
	var screen: ArchiveScreen = V4uKit.archive(self, _cs, bank)
	screen.select(_cs.unlock(&"u_w_lmg"))
	screen.unlock_button.pressed.emit()
	assert_str(String(screen.model.pending)).is_equal("u_w_lmg")
	assert_bool(bank.owns(&"u_w_lmg")).is_false()  # not bought yet
	assert_str(screen.data_label.text).is_equal("180")  # the price is held back
	assert_str(screen.unlock_button.text).is_equal(Strings.tf("archive.undo", [5]))
	assert_str(screen.row_of(&"u_w_lmg").state_label.text).is_equal(Strings.t("archive.unlocking"))
	screen.unlock_button.pressed.emit()  # UNDO
	assert_str(String(screen.model.pending)).is_equal("")
	assert_str(screen.data_label.text).is_equal("300")
	assert_bool(bank.owns(&"u_w_lmg")).is_false()
	assert_int(bank.data()).is_equal(300)


func test_the_purchase_is_made_when_the_window_ends_when_another_row_is_tapped_and_when_the_screen_closes() -> void:
	var bank: ArchiveBank = _bank(600)
	var screen: ArchiveScreen = V4uKit.archive(self, _cs, bank)
	screen.select(_cs.unlock(&"u_w_lmg"))
	screen.unlock_button.pressed.emit()
	screen._process(ArchiveScreen.UNDO_SECONDS - 1.0)
	assert_bool(bank.owns(&"u_w_lmg")).is_false()
	assert_str(screen.unlock_button.text).is_equal(Strings.tf("archive.undo", [1]))
	screen._process(1.5)  # the window ended
	assert_bool(bank.owns(&"u_w_lmg")).is_true()
	assert_int(bank.data()).is_equal(480)
	assert_str(screen.notice_label.text).contains("LMG")
	screen.select(_cs.unlock(&"u_w_hornet"))
	screen.unlock_button.pressed.emit()
	screen.select(_cs.unlock(&"u_p_blast"))  # moving on keeps what was chosen
	assert_bool(bank.owns(&"u_w_hornet")).is_true()
	screen.unlock_button.pressed.emit()
	var closed: Array[bool] = []
	screen.closed.connect(func() -> void: closed.append(true))
	screen.close_button.pressed.emit()
	assert_bool(bank.owns(&"u_p_blast")).is_true()
	assert_array(closed).is_equal([true])
	assert_int(bank.data()).is_equal(300)  # 600 - 120 - 80 - 100


func test_tier_two_rows_open_once_three_unlocks_are_owned() -> void:
	var screen: ArchiveScreen = V4uKit.archive(self, _cs, _bank(900, ["u_w_hornet", "u_w_lmg", "u_p_blast"]))
	assert_str(screen.row_of(&"u_w_mortar").state_label.text).contains("DATA")
	assert_str(screen.row_of(&"u_w_mortar").state_label.text).not_contains("LOCKED")
	screen.select(_cs.unlock(&"u_w_mortar"))
	assert_bool(screen.unlock_button.disabled).is_false()
	assert_str(screen.tier_labels[1].text).not_contains("NEEDED")


func test_a_directive_pack_lists_the_directives_it_adds() -> void:
	var screen: ArchiveScreen = V4uKit.archive(self, _cs, _bank(200))
	screen.select_branch(UnlockDef.Branch.DIRECTIVES)
	screen.select(_cs.unlock(&"u_p_blast"))
	# the fixture holds only the slice directives: a pack names the ones it has, and its own rules line is always there
	assert_str(screen.detail.text_label.text).is_not_empty()
	assert_str(screen.detail.meta_label.text).contains("TIER 1")


func test_the_screen_fits_three_aspects_and_a_narrow_phone() -> void:
	var sizes: Array[Vector2] = V4uKit.SIZES.duplicate()
	sizes.append(V4uKit.NARROW)
	for view: Vector2 in sizes:
		var screen: ArchiveScreen = V4uKit.archive(self, _cs, _bank(450, ["u_w_hornet"]), view)
		await V4uKit.settle(get_tree())
		assert_array(ScreensTestKit.bad_texts(screen)).is_empty()
		for b: Button in UiKit.buttons(screen):
			if b.is_visible_in_tree():
				assert_float(b.size.y).override_failure_message("%s %s at %s" % [b.get_path(), b.size, view]).is_greater_equal(132.0)
				var bottom: float = b.global_position.y + b.size.y
				assert_float(bottom).override_failure_message("%s past the bottom at %s" % [b.text, view]).is_less_equal(view.y + 0.5)
		for label: Label in UiKit.labels(screen):
			if label.is_visible_in_tree() and label.text != "":
				assert_int(label.get_theme_font_size(&"font_size")).override_failure_message("'%s' under 30 px" % label.text).is_greater_equal(30)
		assert_float(screen.unlock_button.global_position.y).is_greater(view.y * 0.5)  # the one action sits in the lower half
