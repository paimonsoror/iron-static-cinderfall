class_name SalvageOverlay
extends RunOverlayBase
## The salvage screen (VARIETY_SPEC 11.3): the recovered weapon against the carried ones; take in a slot, level up or
## scrap. An overlay inside INTERMISSION while RunApi.awaiting() == AWAIT_SALVAGE; sends resolve_salvage(choice, action).
## A normal crate holds one weapon; a boss crate two side by side (tap one first). A duplicate of a carried weapon offers
## LEVEL UP as the highlighted default. Tapping only selects; CONFIRM sends. `setup` is the frozen contract.

const NO_ACTION: int = -1

var offer: Dictionary = {}
var new_panels: Array[SalvageWeaponPanel] = []
var slot_panels: Array[SalvageWeaponPanel] = []
var level_panel: SalvageWeaponPanel
var scrap_panel: SalvageWeaponPanel
var title_label: Label
var carried_label: Label
var choice: int = -1  ## which weapon of the crate (0 unless a boss crate)
var action: int = NO_ACTION  ## a slot 0..2, RunApi.SALVAGE_LEVEL_UP or RunApi.SALVAGE_SCRAP


func setup(api: RunApi, content: ContentSet) -> void:
	_open(api, content)


func _populate() -> void:
	new_panels.clear()
	slot_panels.clear()
	offer = _api.salvage_offer()
	var boss: bool = offer.get("boss", false)
	choice = -1 if boss else 0
	action = NO_ACTION
	_add_info_band(Strings.tf("draft.cleared", [_api.wave()]))
	title_label = RunUi.wrap(RunUi.label(Strings.t("salvage.header"), UiTheme.FONT_LARGE, &"body", true))
	header.add_child(title_label)
	if boss:
		header.add_child(RunUi.label(Strings.t("salvage.pick_one"), RunUi.MIN_TEXT + 4, &"friendly", true))
	_build_new_panels(boss)
	carried_label = RunUi.label(Strings.t("salvage.carried"), RunUi.MIN_TEXT + 4, &"dim", true)
	controls.add_child(carried_label)
	_build_slot_panels()
	level_panel = SalvageWeaponPanel.new()
	level_panel.build_action("", &"tag_tempo", UiTheme.rim(&"core_amber", RunUi.hc()))
	level_panel.tapped.connect(_select_action.bind(RunApi.SALVAGE_LEVEL_UP))
	controls.add_child(level_panel)
	scrap_panel = SalvageWeaponPanel.new()
	var scrap_value: int = offer.get("scrap_value", 0)
	scrap_panel.build_action(Strings.tf("salvage.scrap_it", [scrap_value]), &"scrap", UiTheme.rim(&"gunmetal", RunUi.hc()).lightened(0.3))
	scrap_panel.tapped.connect(_select_action.bind(RunApi.SALVAGE_SCRAP))
	controls.add_child(scrap_panel)
	confirm_button = RunUi.button("", true)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_on_confirm)
	footer.add_child(confirm_button)
	_default_action()
	_relayout()
	_sync()


func _build_new_panels(boss: bool) -> void:
	var ids: Array = offer.get("weapons", [])
	var tiers: Array = offer.get("tiers", [])
	var holder: BoxContainer
	if boss:
		holder = HBoxContainer.new()
	else:
		holder = VBoxContainer.new()
	holder.add_theme_constant_override(&"separation", 16)
	controls.add_child(holder)
	for i: int in ids.size():
		var id: StringName = ids[i]
		var tier: int = tiers[i] if i < tiers.size() else 1
		var panel: SalvageWeaponPanel = SalvageWeaponPanel.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.build_new(id, tier, _content.weapon(id), boss)
		panel.tapped.connect(_on_new.bind(i))
		panel.long_pressed.connect(_on_long.bind(id, 1))
		holder.add_child(panel)
		new_panels.append(panel)


func _build_slot_panels() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	controls.add_child(row)
	for i: int in _api.weapon_slot_count():
		var info: Dictionary = _api.weapon_slot(i)
		var id: StringName = info.get("id", &"")
		var level: int = info.get("level", 1)
		var state: int = info.get("state", RunApi.SLOT_READY)
		var empty: bool = id == &"" or state == RunApi.SLOT_EMPTY
		var panel: SalvageWeaponPanel = SalvageWeaponPanel.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.build_slot(i, id, level, _content.weapon(id), empty)
		panel.tapped.connect(_select_action.bind(i))
		panel.long_pressed.connect(_on_long.bind(id, level))
		row.add_child(panel)
		slot_panels.append(panel)


func _relayout() -> void:
	if level_panel == null:
		return
	var compact: bool = is_compact()
	for panel: SalvageWeaponPanel in new_panels:
		panel.set_compact(compact)
	for panel: SalvageWeaponPanel in slot_panels:
		panel.set_compact(compact)


## The slot a duplicate of the chosen weapon would level up, or -1.
func level_up_slot() -> int:
	var slots: Array = offer.get("level_up_slot", [])
	if choice < 0 or choice >= slots.size():
		return -1
	var slot: int = slots[choice]
	return slot


func _default_action() -> void:
	action = RunApi.SALVAGE_LEVEL_UP if level_up_slot() >= 0 else NO_ACTION


# --- state ---


func refresh() -> void:
	pass


func _sync() -> void:
	var chosen: bool = choice >= 0
	var dup_slot: int = level_up_slot()
	level_panel.visible = dup_slot >= 0
	if dup_slot >= 0:
		var info: Dictionary = _api.weapon_slot(dup_slot)
		var id: StringName = info.get("id", &"")
		var level: int = info.get("level", 1)
		level_panel.name_label.text = Strings.tf("salvage.level_up", [WeaponStats.short_name(id), level, level + 1])
	for i: int in new_panels.size():
		new_panels[i].set_selected(i == choice and new_panels[i].selectable)
	for panel: SalvageWeaponPanel in slot_panels:
		panel.enabled = chosen
		panel.set_selected(chosen and action == panel.slot)
		panel.set_dimmed(not chosen)
	level_panel.enabled = chosen
	level_panel.set_selected(chosen and action == RunApi.SALVAGE_LEVEL_UP)
	scrap_panel.enabled = chosen
	scrap_panel.set_selected(chosen and action == RunApi.SALVAGE_SCRAP)
	scrap_panel.set_dimmed(not chosen)
	confirm_button.text = _confirm_text()
	confirm_button.disabled = not chosen or action == NO_ACTION


func _confirm_text() -> String:
	if choice < 0 or action == NO_ACTION:
		return Strings.t("draft.confirm_none")
	if action == RunApi.SALVAGE_LEVEL_UP:
		return Strings.t("salvage.confirm_level")
	if action == RunApi.SALVAGE_SCRAP:
		return Strings.t("salvage.confirm_scrap")
	var info: Dictionary = _api.weapon_slot(action)
	var id: StringName = info.get("id", &"")
	var state: int = info.get("state", RunApi.SLOT_READY)
	if id == &"" or state == RunApi.SLOT_EMPTY:
		return Strings.tf("salvage.confirm_take", [action + 1])
	return Strings.tf("salvage.confirm_replace", [WeaponStats.name_of(id)])


# --- input ---


## A boss crate: tap one of the two weapons.
func _on_new(i: int) -> void:
	if i == choice:
		return
	_tap_sound()
	choice = i
	_default_action()
	_sync()


func _select_action(which: int) -> void:
	if choice < 0:
		return
	_tap_sound()
	action = which
	_sync()


func _on_confirm() -> void:
	if choice < 0 or action == NO_ACTION:
		deny(confirm_button)
		return
	_tap_sound()
	_api.resolve_salvage(_next_id(), choice, action)
	action = NO_ACTION
	_sync()


func _on_long(id: StringName, level: int) -> void:
	var def: WeaponDef = _content.weapon(id)
	if def == null:
		return
	var panel: RunDetailPanel = RunDetailPanel.new()
	var sub: String = Strings.tf("salvage.tier", [def.tier])
	panel.show_detail(WeaponStats.name_of(id), sub, RunUi.opt("weapon.%s.desc" % String(id)), WeaponStats.parts(def, level), UiTheme.rim(&"warden_cyan", RunUi.hc()))
	open_modal(panel)


func _bind_events() -> void:
	super._bind_events()
	_bind(Events.salvage_offered, _reoffer)


## The next crate of a banked pile: read the offer again.
func _reoffer() -> void:
	notice_label = null
	for band: Control in [header, controls, footer]:
		for child: Node in band.get_children():
			band.remove_child(child)
			child.queue_free()
	_populate()
	refresh_info()
