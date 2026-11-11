class_name BootScreen
extends Control
## First screen (GDD 10.2): the title over the freight-yard backdrop, three status lines, the build version and a
## short progress bar. It ends by itself after AUTO_SECONDS (the GDD allows 3 s at most) or when CONTINUE is pressed;
## `finished` is emitted once. The signal and setup() are the frozen contract (ARCH 9).

signal finished

const AUTO_SECONDS: float = 2.6
const STATUS_KEYS: Array[String] = ["lore.boot.status.1", "lore.boot.status.2", "lore.boot.status.3"]

var title_block: UiTitleBlock
var tagline_label: Label
var status_labels: Array[Label] = []
var version_label: Label
var progress: ProgressBar
var continue_button: Button
var _frame: UiScreenFrame
var _built: bool = false
var _elapsed: float = 0.0
var _running: bool = false
var _done: bool = false


func _ready() -> void:
	_ensure_built()


func setup(version: String) -> void:
	_ensure_built()
	version_label.text = Strings.tf("boot.version", [version])
	_elapsed = 0.0
	_running = not _done
	set_process(_running)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	progress.value = clampf(_elapsed / AUTO_SECONDS, 0.0, 1.0) * progress.max_value
	if _elapsed >= AUTO_SECONDS:
		_finish()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_frame = UiScreenFrame.new(UiBackdrop.Mode.HERO)
	add_child(_frame)
	var col: VBoxContainer = _frame.content
	col.add_child(UiKit.spacer(60.0))
	title_block = UiTitleBlock.new(true)
	col.add_child(title_block)
	tagline_label = UiKit.label_text(Strings.t("lore.tagline"), UiTheme.LABEL_DIM)
	tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tagline_label)
	col.add_child(UiKit.spacer(0.0, 0.0, true))
	col.add_child(_status_panel())
	progress = UiKit.bar()
	progress.max_value = 100.0
	progress.value = 0.0
	col.add_child(progress)
	continue_button = UiKit.button_primary("boot.continue")
	continue_button.pressed.connect(_finish)
	_frame.footer.add_child(continue_button)


func _status_panel() -> PanelContainer:
	var panel: PanelContainer = UiKit.panel_variant(UiTheme.PANEL_INSET)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	for key: String in STATUS_KEYS:
		var l: Label = UiKit.label_text(Strings.t(key), &"Mono", 34)
		status_labels.append(l)
		col.add_child(l)
	version_label = UiKit.label_text("", &"Mono", 34)
	col.add_child(version_label)
	return panel


## Emits `finished` the first time only, whichever of the timer and the button comes first.
func _finish() -> void:
	if _done:
		return
	_done = true
	_running = false
	set_process(false)
	finished.emit()
