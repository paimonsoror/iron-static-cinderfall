class_name ArchiveScreen
extends Control
## The Archive (GDD 8.5, 10.7; VARIETY_SPEC 11.6): where Recovered Data buys variety. A title and the Data held, four tabs
## (ARMORY, DIRECTIVES, KITS, FIELD), the rows of a tab by tier (a closed tier says how many unlocks it needs), a detail panel
## for the selected row and an UNLOCK button that names the price. There is no second confirm tap: the purchase waits UNDO_SECONDS
## behind an UNDO button, then it is bought (also when the screen is closed or another row is tapped). It reads and writes the
## profile through an `ArchiveBank` (`Save` by default). `closed` and `setup(content)` follow ARCH 9; the optional `bank` is for
## sandboxes and tests.

signal closed

const UNDO_SECONDS: float = 5.0
const COLUMNS: int = 2

var model: ArchiveModel
var branch: int = UnlockDef.Branch.ARMORY
var selected: UnlockDef
var tab_buttons: Array[Button] = []
var rows: Array[ArchiveRow] = []
var tier_labels: Array[Label] = []
var title_label: Label
var sub_label: Label
var data_label: Label
var detail: ArchiveDetail
var unlock_button: Button
var close_button: Button
var notice_label: Label
var _frame: UiScreenFrame
var _undo_left: float = 0.0
var _content: ContentSet
var _built: bool = false


func _ready() -> void:
	_ensure_built()


func setup(content: ContentSet, bank: ArchiveBank = null) -> void:
	_ensure_built()
	_content = content
	model = ArchiveModel.new(content, bank if bank != null else SaveArchiveBank.new(content))
	set_process(false)
	select_branch(UnlockDef.Branch.ARMORY)


func _exit_tree() -> void:
	if model != null and model.pending != &"":
		var _result: int = model.commit()  # the screen left mid-window: the player chose it and did not undo it


func _process(delta: float) -> void:
	if model == null or model.pending == &"":
		set_process(false)
		return
	_undo_left -= delta
	if _undo_left <= 0.0:
		_commit()
	else:
		_refresh_button()


## Shows the tab of `new_branch` (an UnlockDef.Branch). A purchase in its window is bought first.
func select_branch(new_branch: int) -> void:
	_commit()
	branch = new_branch
	for i: int in tab_buttons.size():
		tab_buttons[i].set_pressed_no_signal(ArchiveModel.BRANCHES[i] == branch)
	selected = null
	_fill_rows()
	var first: UnlockDef = _first_buyable()
	select(first if first != null else _first_row())


## Selects a row and shows it in the detail panel.
func select(def: UnlockDef) -> void:
	if model != null and model.pending != &"" and (def == null or def.id != model.pending):
		_commit()
	selected = def
	_refresh()


## The row of `id` on the open tab, or null.
func row_of(id: StringName) -> ArchiveRow:
	for row: ArchiveRow in rows:
		if row.def.id == id:
			return row
	return null


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame = UiScreenFrame.new(UiBackdrop.Mode.PLAIN)
	add_child(_frame)
	var head: HBoxContainer = HBoxContainer.new()
	_frame.header.add_child(head)
	title_label = UiKit.label_text(Strings.t("archive.title"), UiTheme.LABEL_HEADING, UiTheme.FONT_LARGE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var data_box: VBoxContainer = VBoxContainer.new()
	data_box.add_theme_constant_override(&"separation", 0)
	head.add_child(data_box)
	data_box.add_child(UiKit.label_text(Strings.t("archive.data"), UiTheme.LABEL_CAPTION))
	data_label = UiKit.label_text("0", UiTheme.LABEL_NUMBER, UiTheme.FONT_LARGE)
	data_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	data_box.add_child(data_label)
	sub_label = UiKit.label_text(Strings.t("archive.sub"), UiTheme.LABEL_DIM, RunUi.MIN_TEXT)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frame.header.add_child(sub_label)
	_frame.header.add_child(_tabs())
	_frame.content.add_theme_constant_override(&"separation", 14)
	detail = ArchiveDetail.new()
	_frame.footer.add_child(detail)
	notice_label = UiKit.label_text("", UiTheme.LABEL_FRIENDLY, RunUi.MIN_TEXT)
	notice_label.visible = false
	_frame.footer.add_child(notice_label)
	unlock_button = UiKit.button_primary("archive.unlock_none")
	unlock_button.custom_minimum_size = Vector2(0.0, UiTheme.BTN_PRIMARY_H)
	unlock_button.pressed.connect(_on_unlock)
	_frame.footer.add_child(unlock_button)
	close_button = UiKit.button_quiet("ui.close")
	close_button.pressed.connect(close)
	_frame.footer.add_child(close_button)


func _tabs() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in ArchiveModel.BRANCHES.size():
		var b: Button = UiKit.button("archive.tab.%s" % UnlockDef.BRANCH_NAMES[ArchiveModel.BRANCHES[i]])
		b.theme_type_variation = UiTheme.BUTTON_SEGMENT
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0.0, UiTheme.TOUCH_MIN)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY - 4)
		b.pressed.connect(select_branch.bind(ArchiveModel.BRANCHES[i]))
		row.add_child(b)
		tab_buttons.append(b)
	return row


## One tier heading and a two-column grid of rows per tier of the open tab.
func _fill_rows() -> void:
	for child: Node in _frame.content.get_children():
		_frame.content.remove_child(child)
		child.queue_free()
	rows.clear()
	tier_labels.clear()
	for tier: int in model.tiers(branch):
		var open: bool = model.tier_open(tier)
		var text: String = Strings.tf("archive.tier", [tier])
		if not open:
			text = Strings.tf("archive.tier_gate", [tier, ArchiveModel.gate(_content, tier), model.owned_total(), ArchiveModel.gate(_content, tier)])
		var heading: Label = UiKit.label_text(text, UiTheme.LABEL_ACCENT if open else UiTheme.LABEL_DIM, UiTheme.FONT_BODY)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_frame.content.add_child(heading)
		tier_labels.append(heading)
		var grid: GridContainer = GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override(&"h_separation", 14)
		grid.add_theme_constant_override(&"v_separation", 14)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_frame.content.add_child(grid)
		for def: UnlockDef in model.rows(branch):
			if def.tier != tier:
				continue
			var row: ArchiveRow = ArchiveRow.new()
			row.build(def, _content)
			row.tapped.connect(_on_row.bind(def))
			grid.add_child(row)
			rows.append(row)


func _first_buyable() -> UnlockDef:
	for row: ArchiveRow in rows:
		if model.state(row.def) == ArchiveModel.State.AVAILABLE:
			return row.def
	return null


func _first_row() -> UnlockDef:
	return rows[0].def if not rows.is_empty() else null


func _refresh() -> void:
	if model == null:
		return
	data_label.text = UiKit.group(model.data())
	for row: ArchiveRow in rows:
		var state: int = model.state(row.def)
		row.set_state(state, row.def.cost - model.data())
		row.set_selected(selected != null and row.def.id == selected.id)
	if selected != null:
		var s: int = model.state(selected)
		detail.show_row(selected, _content, s, selected.cost - model.data(), ArchiveModel.gate(_content, selected.tier) - model.owned_total())
	else:
		detail.show_row(null, _content, ArchiveModel.State.POOR, 0, 0)
	_refresh_button()


func _refresh_button() -> void:
	if selected == null:
		unlock_button.text = Strings.t("archive.unlock_none")
		unlock_button.disabled = true
		return
	var state: int = model.state(selected)
	unlock_button.disabled = state != ArchiveModel.State.AVAILABLE and state != ArchiveModel.State.PENDING
	match state:
		ArchiveModel.State.PENDING:
			unlock_button.text = Strings.tf("archive.undo", [ceili(_undo_left)])
		ArchiveModel.State.AVAILABLE:
			unlock_button.text = Strings.tf("archive.unlock_for", [UiKit.group(selected.cost)])
		ArchiveModel.State.OWNED:
			unlock_button.text = Strings.t("archive.owned")
		ArchiveModel.State.TIER_LOCKED:
			unlock_button.text = Strings.tf("archive.gate_needed", [ArchiveModel.gate(_content, selected.tier) - model.owned_total()])
		_:
			unlock_button.text = Strings.tf("archive.need_data", [UiKit.group(maxi(selected.cost - model.data(), 0))])


func _on_row(def: UnlockDef) -> void:
	Sfx.play(&"ui_tap")
	select(def)


## UNLOCK starts the UNDO window; the same button then reads UNDO and cancels it.
func _on_unlock() -> void:
	if selected == null or model == null:
		return
	if model.pending == selected.id:
		Sfx.play(&"ui_tap")
		model.release()
		set_process(false)
		_show_notice("")
		_refresh()
		return
	if not model.hold(selected):
		Sfx.play(&"ui_deny")
		return
	Sfx.play(&"ui_tap")
	_undo_left = UNDO_SECONDS
	set_process(true)
	_show_notice("")
	_refresh()


## Buys the purchase in its window now (a no-op when there is none).
func _commit() -> void:
	if model == null or model.pending == &"":
		return
	var def: UnlockDef = _content.unlock(model.pending)
	var result: int = model.commit()
	set_process(false)
	if result == Reason.Id.OK:
		Sfx.play(&"ui_purchase")
		_show_notice(Strings.tf("archive.unlocked", [ArchiveModel.display_name(def)]) if def != null else "")
	else:
		Sfx.play(&"ui_deny")
		_show_notice(_reason_text(result))
	_refresh()


func close() -> void:
	_commit()
	closed.emit()


func _show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.visible = text != ""


static func _reason_text(reason: int) -> String:
	match reason:
		Reason.Id.INSUFFICIENT_SCRAP:
			return Strings.t("archive.reason.data")
		Reason.Id.PREREQ_NOT_MET:
			return Strings.t("archive.reason.tier")
	return RunUi.opt(Reason.string_key(reason))
