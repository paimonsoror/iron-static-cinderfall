class_name DraftOverlay
extends RunOverlayBase
## The draft screen (VARIETY_SPEC 11.1): 1 of 3 directives (1 of 4 with quartermaster), reroll, patch, skip, buy-out, two-tap
## confirm. An overlay inside INTERMISSION while RunApi.awaiting() == AWAIT_DRAFT; it reads the offer from the RunApi and
## sends pick_directive, skip_draft, reroll_draft, buy_out and patch_core. A tap on a card (or on SKIP) only selects;
## CONFIRM sends. A staged BUY-OUT ("KEEP ALSO 250" on an unselected card) goes out with the pick, buy_out first. A long
## press on a card shows its full rules and what it works with. The build button (tall screens) opens the BuildList.
## `setup` is the frozen contract.

const SKIP: int = -2  ## `selected_slot` when SKIP is the choice

var cards: Array[DirectiveCard] = []
var reroll_button: Button
var patch_button: Button
var skip_button: Button
var build_button: Button
var title_label: Label
var sub_label: Label
var corrupted_label: Label
var build_info: Label  ## the compact build line (information only), replaces build_button on a near-square screen
var selected_slot: int = -1
var buyout_slot: int = -1
var _cards_row: HBoxContainer


func setup(api: RunApi, content: ContentSet) -> void:
	_open(api, content)


func _populate() -> void:
	cards.clear()
	corrupted_label = null
	selected_slot = -1
	buyout_slot = -1
	_add_info_band(Strings.tf("draft.cleared", [_api.wave()]))
	title_label = RunUi.label(Strings.t("draft.header"), 44, &"body", true)
	header.add_child(title_label)
	sub_label = RunUi.label(Strings.t("draft.sub"), RunUi.MIN_TEXT, &"dim")
	header.add_child(sub_label)
	build_info = RunUi.label("", RunUi.MIN_TEXT, &"dim")
	build_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(build_info)
	build_button = _make_build_button()
	controls.add_child(build_button)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override(&"separation", 14)
	controls.add_child(_cards_row)
	_make_footer()
	_build_cards()


func _make_footer() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	reroll_button = _action_button(_on_reroll)
	patch_button = _action_button(_on_patch)
	skip_button = _action_button(_on_skip)
	skip_button.toggle_mode = true
	skip_button.theme_type_variation = UiTheme.BUTTON_SEGMENT
	row.add_child(reroll_button)
	row.add_child(patch_button)
	row.add_child(skip_button)
	footer.add_child(row)
	confirm_button = RunUi.button("", true)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_on_confirm)
	footer.add_child(confirm_button)


func _action_button(handler: Callable) -> Button:
	var b: Button = RunUi.button("", false, RunUi.MIN_TEXT + 2)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(handler)
	return b


## The wide BUILD button: the tags held as chips and the weapons carried. Tapping it opens the BuildList.
func _make_build_button() -> Button:
	var b: Button = RunUi.button("", false)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_on_build_pressed)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	UiKit.fill(row)
	row.offset_left = 18.0
	row.offset_right = -18.0
	row.add_child(RunUi.label(Strings.t("draft.build"), RunUi.MIN_TEXT, &"dim", true))
	var tags: Array[StringName] = _tags_by_stacks()
	for tag: StringName in tags:
		var chip: PanelContainer = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override(&"panel", RunUi.chip_box(UiTheme.rim(&"warden_cyan", RunUi.hc())))
		chip.add_child(RunUi.label(_chip_text(tag), RunUi.MIN_TEXT, &"friendly", true))
		row.add_child(chip)
	if tags.is_empty():
		row.add_child(RunUi.label(Strings.t("draft.nothing_yet"), RunUi.MIN_TEXT, &"dim"))
	var weapons: Label = RunUi.label("%s %s" % [Strings.t("draft.weapons"), _weapon_names()], RunUi.MIN_TEXT, &"body", true)
	weapons.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weapons.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(weapons)
	return b


## The tags held, most stacks first (at most four).
func _tags_by_stacks() -> Array[StringName]:
	var tags: Array[StringName] = []
	var stacks: Dictionary = _api.build_tags()
	for key: Variant in stacks.keys():
		var tag: StringName = key
		var n: int = stacks[key]
		if n > 0:
			tags.append(tag)
	tags.sort_custom(_tag_before)
	return tags.slice(0, 4)


func _tag_before(a: StringName, b: StringName) -> bool:
	var stacks: Dictionary = _api.build_tags()
	var sa: int = stacks.get(a, 0)
	var sb: int = stacks.get(b, 0)
	return sa > sb or (sa == sb and String(a) < String(b))


func _chip_text(tag: StringName) -> String:
	var stacks: Dictionary = _api.build_tags()
	var n: int = stacks.get(tag, 0)
	return "%s %s" % [RunUi.tag_name(tag), Strings.tf("build.stacks", [n])]


func _chips_line() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for tag: StringName in _tags_by_stacks():
		parts.append(_chip_text(tag))
	return "  ".join(parts)


func _weapon_names() -> String:
	var names: PackedStringArray = PackedStringArray()
	for i: int in _api.weapon_slot_count():
		var wid: StringName = _api.weapon_slot(i).get("id", &"")
		if wid != &"":
			names.append(RunUi.opt("weapon.%s.short" % String(wid), String(wid).to_upper()))
	return "  ".join(names)


## Rebuilds the cards from the offer. `keep` keeps a still-valid selection (a directive was just taken from a draft that
## stays open: the picked slot reads -1 now, the selection on another slot survives); a new offer clears it.
func _build_cards(keep: bool = false) -> void:
	for child: Node in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	cards.clear()
	var kept_pick: int = selected_slot if keep else -1
	var kept_buyout: int = buyout_slot if keep else -1
	selected_slot = -1
	buyout_slot = -1
	var offer: PackedInt32Array = _api.draft_offer()
	var any_corrupted: bool = false
	for slot: int in offer.size():
		var index: int = offer[slot]
		var def: DirectiveDef = _content.directives[index] if index >= 0 and index < _content.directives.size() else null
		var card: DirectiveCard = DirectiveCard.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var held: int = _api.directive_stacks(def.id) if def != null else 0
		card.build(slot, def, held, offer.size() >= 4)
		card.tapped.connect(_on_card.bind(slot))
		card.long_pressed.connect(_on_long.bind(slot))
		card.buyout_toggled.connect(_on_buyout.bind(slot))
		_cards_row.add_child(card)
		cards.append(card)
		any_corrupted = any_corrupted or card.is_corrupted()
	if any_corrupted and corrupted_label == null:
		corrupted_label = RunUi.label(Strings.t("draft.corrupted.tag"), RunUi.MIN_TEXT, &"danger", true)
		header.add_child(corrupted_label)
	if corrupted_label != null:
		corrupted_label.visible = any_corrupted
	if kept_pick == SKIP or (kept_pick >= 0 and kept_pick < cards.size() and cards[kept_pick].enabled):
		selected_slot = kept_pick
		if kept_buyout >= 0 and kept_buyout < cards.size() and cards[kept_buyout].enabled and kept_buyout != kept_pick:
			buyout_slot = kept_buyout
	_relayout()
	_sync()


func _relayout() -> void:
	if _cards_row == null:
		return
	var h: float = size.y if size.y > 2.0 else 1920.0
	var card_h: float = clampf(h * 0.29, 440.0, 560.0)
	for card: DirectiveCard in cards:
		card.custom_minimum_size.y = card_h
	build_button.visible = h >= COMPACT_HEIGHT
	build_info.visible = h < COMPACT_HEIGHT
	sub_label.visible = h >= COMPACT_HEIGHT
	build_info.text = "%s  %s    %s %s" % [Strings.t("draft.build"), _chips_line(), Strings.t("draft.weapons"), _weapon_names()]


# --- state ---


func refresh() -> void:
	if reroll_button == null:
		return
	_refresh_prices()
	_sync_buyouts()


func _refresh_prices() -> void:
	var reroll_cost: int = _api.draft_reroll_cost()
	var open: bool = not _api.draft_actions_locked()  # NO BREATHER: neither a reroll nor a patch in this draft
	reroll_button.text = Strings.t("draft.reroll_free") if reroll_cost <= 0 else Strings.tf("draft.reroll", [reroll_cost])
	reroll_button.modulate = _dim(open and (reroll_cost <= 0 or _api.scrap() >= reroll_cost))
	patch_button.text = Strings.tf("draft.patch", [_patch_pct(), _api.patch_cost()])
	patch_button.modulate = _dim(open and _api.scrap() >= _api.patch_cost())
	skip_button.text = Strings.tf("draft.skip", [_skip_scrap()])


func _dim(ok: bool) -> Color:
	return Color.WHITE if ok else Color(1.0, 1.0, 1.0, 0.6)


func _patch_pct() -> int:
	return roundi(_content.run.patch_frac * 100.0) if _content.run != null else 10


func _skip_scrap() -> int:
	return _content.run.draft_skip_scrap if _content.run != null else 60


## Selection, buy-out buttons, SKIP and CONFIRM from `selected_slot` and `buyout_slot`.
func _sync() -> void:
	for card: DirectiveCard in cards:
		var on: bool = card.slot == selected_slot
		card.set_selected(on)
		card.set_dimmed(selected_slot != -1 and not on and card.enabled)
	skip_button.set_pressed_no_signal(selected_slot == SKIP)
	_refresh_prices()
	_sync_buyouts()
	confirm_button.text = _confirm_text()
	confirm_button.disabled = selected_slot == -1


func _sync_buyouts() -> void:
	var cost: int = _api.draft_buyout_cost()
	for card: DirectiveCard in cards:
		var show: bool = selected_slot >= 0 and card.slot != selected_slot and card.def != null and cost > 0 and not _api.draft_buyout_used()
		card.set_buyout(show, cost, card.slot == buyout_slot, _api.scrap() >= cost)


func _confirm_text() -> String:
	if selected_slot == SKIP:
		return Strings.tf("draft.confirm", [Strings.tf("draft.skip", [_skip_scrap()])])
	if selected_slot < 0 or selected_slot >= cards.size():
		return Strings.t("draft.confirm_none")
	var picked: String = Strings.t(cards[selected_slot].def.name_key)
	if buyout_slot >= 0 and buyout_slot < cards.size() and cards[buyout_slot].def != null:
		return Strings.tf("draft.confirm_both", [picked, Strings.t(cards[buyout_slot].def.name_key)])
	return Strings.tf("draft.confirm", [picked])


# --- input ---


func _on_card(slot: int) -> void:
	if slot < 0 or slot >= cards.size() or not cards[slot].enabled:
		return
	_tap_sound()
	selected_slot = slot
	if buyout_slot == slot:
		buyout_slot = -1
	_sync()


func _on_skip() -> void:
	_tap_sound()
	selected_slot = SKIP
	buyout_slot = -1
	_sync()


func _on_buyout(slot: int) -> void:
	var cost: int = _api.draft_buyout_cost()
	if _api.draft_buyout_used():
		buyout_slot = -1
	elif buyout_slot == slot:
		buyout_slot = -1
	elif _api.scrap() < cost:
		deny(cards[slot].buyout_button, RunUi.opt("reason.insufficient_scrap"))
	else:
		_tap_sound()
		buyout_slot = slot
	_sync()


func _on_confirm() -> void:
	if selected_slot == -1:
		deny(confirm_button)
		return
	_tap_sound()
	var pick: int = selected_slot  # the API's signals may rebuild the cards while the commands go out
	var keep: int = buyout_slot
	if pick == SKIP:
		_api.skip_draft(_next_id())
	else:
		if keep >= 0:
			_api.buy_out(_next_id(), keep)
		_api.pick_directive(_next_id(), pick)
	selected_slot = -1
	buyout_slot = -1
	_sync()


func _on_reroll() -> void:
	if _api.draft_actions_locked():
		deny(reroll_button, RunUi.opt("reason.locked_by_event"))
		return
	var cost: int = _api.draft_reroll_cost()
	if cost > 0 and _api.scrap() < cost:
		deny(reroll_button, RunUi.opt("reason.insufficient_scrap"))
		return
	_tap_sound()
	_api.reroll_draft(_next_id())
	selected_slot = -1
	buyout_slot = -1
	_sync()


func _on_patch() -> void:
	if _api.draft_actions_locked():
		deny(patch_button, RunUi.opt("reason.locked_by_event"))
		return
	if _api.scrap() < _api.patch_cost():
		deny(patch_button, RunUi.opt("reason.insufficient_scrap"))
		return
	_tap_sound()
	_api.patch_core(_next_id())


func _on_build_pressed() -> void:
	_tap_sound()
	var list: BuildList = BuildList.new()
	list.setup(_api, _content)
	open_modal(list)


func _on_long(slot: int) -> void:
	if slot < 0 or slot >= cards.size() or cards[slot].def == null:
		return
	var def: DirectiveDef = cards[slot].def
	var rules: String = RunUi.opt("directive.%s.rules" % String(def.id), Strings.t(def.desc_key))
	var tags: PackedStringArray = PackedStringArray()
	for tag: StringName in def.tags:
		tags.append(RunUi.tag_name(tag))
	var rarity: String = Strings.t("directive.rarity.%s" % DirectiveDef.RARITY_NAMES[def.rarity])
	var extra: PackedStringArray = PackedStringArray()
	if def.rarity == DirectiveDef.Rarity.CORRUPTED:
		extra.append("%s: %s" % [Strings.t("directive.price_label"), Strings.t("directive.%s.price" % String(def.id))])
	var with: PackedStringArray = RunUi.works_with(_api, _content, def)
	if not with.is_empty():
		extra.append(Strings.tf("directive.works_with", [", ".join(with)]))
	var panel: RunDetailPanel = RunDetailPanel.new()
	panel.show_detail(Strings.t(def.name_key), "%s  //  %s" % [rarity, " ".join(tags)], rules, extra, cards[slot].rim_color)
	open_modal(panel)


func _bind_events() -> void:
	super._bind_events()
	_bind(Events.draft_offered, func(_ids: Array[StringName]) -> void: _build_cards())
	_bind(Events.directive_picked, func(_id: StringName, _stacks: int) -> void: _build_cards(true))
