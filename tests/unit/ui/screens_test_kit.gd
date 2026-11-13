class_name ScreensTestKit
extends RefCounted
## Helpers shared by the meta-screen and kit tests (not a suite itself).

const BOOT: String = "res://src/ui/screens/boot_screen.tscn"
const MENU: String = "res://src/ui/screens/main_menu_screen.tscn"
const BRIEFING: String = "res://src/ui/screens/briefing_screen.tscn"
const RESULTS: String = "res://src/ui/screens/results_screen.tscn"
const SETTINGS: String = "res://src/ui/screens/settings_screen.tscn"


## A plain Control of `view_size` inside the suite: the stand-in for a screen layer. Full-rect children take its size.
static func host(suite: GdUnitTestSuite, view_size: Vector2 = Vector2(1080.0, 2400.0)) -> Control:
	var node: Control = Control.new()
	suite.auto_free(node)
	node.size = view_size
	suite.add_child(node)
	return node


## Instantiates the screen scene at `path` under a fresh host. Call its setup() afterwards.
static func screen(suite: GdUnitTestSuite, path: String, view_size: Vector2 = Vector2(1080.0, 2400.0)) -> Control:
	var packed: PackedScene = load(path) as PackedScene
	var node: Control = packed.instantiate() as Control
	host(suite, view_size).add_child(node)
	return node


## Lets layout and deferred calls run.
static func settle(tree: SceneTree, frames: int = 3) -> void:
	for i: int in frames:
		await tree.process_frame


## Points the Save autoload at an empty in-memory profile (no disk, defaults).
static func fresh_save() -> void:
	Save.use_fs(MemorySaveFs.new())
	Save.load_profile()


## Labels and buttons below `root` whose text is a "#key#" placeholder from Strings, or is empty while they are on screen (a
## hidden label waiting for its text, like the milestone line, is not a defect).
static func bad_texts(root: Node) -> Array[String]:
	var bad: Array[String] = []
	for l: Label in UiKit.labels(root):
		if _is_bad(l.text) and (l.text.strip_edges() != "" or l.is_visible_in_tree()):
			bad.append("%s '%s'" % [l.get_path(), l.text])
	for b: Button in UiKit.buttons(root):
		if _is_bad(b.text) and (b.text.strip_edges() != "" or b.is_visible_in_tree()):
			bad.append("%s '%s'" % [b.get_path(), b.text])
	return bad


## Buttons below `root` narrower or shorter than UiTheme.TOUCH_MIN once laid out.
static func small_buttons(root: Node) -> Array[String]:
	var small: Array[String] = []
	for b: Button in UiKit.buttons(root):
		if b.size.x < float(UiTheme.TOUCH_MIN) or b.size.y < float(UiTheme.TOUCH_MIN):
			small.append("%s %s" % [b.get_path(), b.size])
	return small


## Every string key written as a "group.name" literal in the .gd files of `dir` (formats such as "x.%s" are skipped).
static func literal_keys(dir: String) -> Array[String]:
	var found: Array[String] = []
	var rx: RegEx = RegEx.new()
	rx.compile("\"((?:boot|menu|briefing|results|settings|lore)\\.[a-z0-9_.]*[a-z0-9_])\"")
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string(dir + "/" + file)
		for m: RegExMatch in rx.search_all(source):
			var key: String = m.get_string(1)
			if not found.has(key):
				found.append(key)
	return found


static func _is_bad(text: String) -> bool:
	var t: String = text.strip_edges()
	return t == "" or (t.begins_with("#") and t.ends_with("#"))
