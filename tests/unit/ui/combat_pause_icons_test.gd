extends GdUnitTestSuite
## PauseOverlay (frozen signals, big buttons) and the authored SVG icons.

const ICON_IDS: Array[StringName] = [
	&"damage", &"fire_rate", &"armor_piercing", &"auto_turret", &"smg_unlock",
	&"emp", &"shield", &"overdrive", &"scrap", &"core", &"pause",
]


func _overlay() -> PauseOverlay:
	var packed: PackedScene = load("res://src/ui/combat/pause_overlay.tscn") as PackedScene
	var overlay: PauseOverlay = packed.instantiate() as PauseOverlay
	CombatHudTestKit.screen(self, Vector2(1080.0, 1920.0)).add_child(overlay)
	overlay.setup()
	return overlay


func test_the_pause_overlay_buttons_emit_their_signals_once() -> void:
	var overlay: PauseOverlay = _overlay()
	var hits: Array[String] = []
	overlay.resume_pressed.connect(func() -> void: hits.append("resume"))
	overlay.restart_pressed.connect(func() -> void: hits.append("restart"))
	overlay.settings_pressed.connect(func() -> void: hits.append("settings"))
	overlay.quit_pressed.connect(func() -> void: hits.append("quit"))
	overlay.resume_button.pressed.emit()
	overlay.restart_button.pressed.emit()
	overlay.settings_button.pressed.emit()
	overlay.quit_button.pressed.emit()
	assert_array(hits).is_equal(["resume", "restart", "settings", "quit"])


func test_the_pause_overlay_text_comes_from_the_string_table_and_buttons_are_big() -> void:
	var overlay: PauseOverlay = _overlay()
	await CombatHudTestKit.settle(get_tree())
	assert_str(overlay.title_label.text).is_equal(Strings.t("pause.title"))
	assert_str(overlay.resume_button.text).is_equal(Strings.t("pause.resume"))
	assert_str(overlay.restart_button.text).is_equal(Strings.t("pause.restart"))
	assert_str(overlay.settings_button.text).is_equal(Strings.t("pause.settings"))
	assert_str(overlay.quit_button.text).is_equal(Strings.t("pause.quit"))
	for b: BaseButton in CombatHudTestKit.buttons(overlay):
		assert_float(b.size.x).is_greater_equal(132.0)
		assert_float(b.size.y).is_greater_equal(148.0)
	assert_int(CombatHudTestKit.buttons(overlay).size()).is_equal(4)


func test_the_pause_overlay_blocks_taps_to_whatever_is_below_it() -> void:
	var overlay: PauseOverlay = _overlay()
	assert_int(overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_every_icon_exists_and_is_128_by_128() -> void:
	for id: StringName in ICON_IDS:
		var path: String = "res://assets/icons/%s.svg" % String(id)
		assert_bool(ResourceLoader.exists(path)).is_true()
		var tex: Texture2D = load(path) as Texture2D
		assert_object(tex).is_not_null()
		assert_int(tex.get_width()).is_equal(128)
		assert_int(tex.get_height()).is_equal(128)


func test_every_icon_file_is_flat_two_tone_with_no_gradients_or_raster() -> void:
	for id: StringName in ICON_IDS:
		var text: String = FileAccess.get_file_as_string("res://assets/icons/%s.svg" % String(id))
		assert_bool(text.contains("Gradient")).is_false()
		assert_bool(text.contains("<image")).is_false()
		var colors: Dictionary = {}
		var rx: RegEx = RegEx.create_from_string("#[0-9A-Fa-f]{6}")
		for m: RegExMatch in rx.search_all(text):
			colors[m.get_string().to_upper()] = true
		assert_int(colors.size()).is_equal(2)


func test_the_hud_scene_root_is_a_combat_hud_and_the_pause_scene_a_pause_overlay() -> void:
	var hud_packed: PackedScene = load("res://src/ui/combat/combat_hud.tscn") as PackedScene
	var hud_node: Node = auto_free(hud_packed.instantiate())
	assert_bool(hud_node is CombatHud).is_true()
	var pause_packed: PackedScene = load("res://src/ui/combat/pause_overlay.tscn") as PackedScene
	var pause_node: Node = auto_free(pause_packed.instantiate())
	assert_bool(pause_node is PauseOverlay).is_true()
