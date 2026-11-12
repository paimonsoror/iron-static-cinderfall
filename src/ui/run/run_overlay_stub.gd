class_name RunOverlayStub
extends RefCounted
## Shared body of the four intermission overlay stubs (V1-S scaffold): a dimmed full-rect scrim, the header of the
## screen and one line per choice the RunApi offers, so a sandbox capture shows that the data arrives. V2-E replaces
## each overlay's body with the real screen of VARIETY_SPEC 11.1 to 11.3 and deletes this file.
# TODO(V2-E)


static func build(root: Control, header_key: String, lines: PackedStringArray) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.78)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	center.add_child(col)
	col.add_child(UiKit.label_text(Strings.t(header_key), &"", UiTheme.FONT_LARGE))
	for line: String in lines:
		col.add_child(UiKit.label_text(line))
	return col
