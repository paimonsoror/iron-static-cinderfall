class_name UiOverflowKit
extends RefCounted
## A generic width check for any screen or overlay (V4-U, after the Archive overflowed a 1080 x 2342 phone). It works on the real
## layout, not on minimum sizes alone: put the screen under a host of the viewport's size, let a few frames lay it out, then ask
## which visible Controls stick out sideways. A container whose minimum width beats the viewport grows past it, so the
## guilty child (a label that cannot wrap, a row that cannot shrink) shows up with its own path and size. Controls inside a
## ScrollContainer that scrolls sideways (the kit row) are meant to extend and are skipped, as are Controls that clip
## their children. Vertical overflow is not asked: screens scroll or trim their height on their own.

## The viewports a screen has to fit: a tall phone, the Pixel's outer display (aspect 0.461), a very tall phone, a near-square window
## and a narrower window (the game's canvas never gets narrower than 1080: the stretch mode expands the height, so the narrow
## ones are headroom). SIZES_NARROW adds the narrowest width the Archive promises.
const SIZES: Array[Vector2] = [
	Vector2(1080.0, 2400.0), Vector2(1080.0, 2342.0), Vector2(1080.0, 2640.0), Vector2(1080.0, 1120.0), Vector2(900.0, 2000.0),
]
const SIZES_NARROW: Array[Vector2] = [
	Vector2(1080.0, 2400.0), Vector2(1080.0, 2342.0), Vector2(1080.0, 2640.0), Vector2(1080.0, 1120.0), Vector2(900.0, 2000.0),
	Vector2(720.0, 1600.0),
]


## A plain Control of `view_size` inside `suite`: the stand-in for a screen layer. Children anchored to it take its size.
static func host(suite: GdUnitTestSuite, view_size: Vector2) -> Control:
	var node: Control = Control.new()
	suite.auto_free(node)
	node.custom_minimum_size = view_size
	node.size = view_size
	suite.add_child(node)
	return node


## Lets the layout settle.
static func settle(tree: SceneTree, frames: int = 4) -> void:
	for i: int in frames:
		await tree.process_frame


## Every visible Control below `root` (and `root` itself) whose rect leaves 0..view.x sideways, as "path pos size". Empty = fits.
static func overflowing(root: Control, view: Vector2, tolerance: float = 0.5) -> Array[String]:
	var out: Array[String] = []
	_walk(root, view, tolerance, out)
	return out


## The widest visible Control below `root` (the first thing to look at when something overflows), "path width".
static func widest(root: Control) -> String:
	var best: Control = root
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var c: Control = node as Control
		if c != null and c.is_visible_in_tree() and c.size.x > best.size.x and c != root:
			best = c
		for child: Node in node.get_children():
			stack.append(child)
	return "%s %.0f" % [best.get_path(), best.size.x]


static func _walk(node: Node, view: Vector2, tolerance: float, out: Array[String]) -> void:
	var c: Control = node as Control
	if c != null:
		if not c.visible:
			return
		var left: float = c.global_position.x
		var right: float = left + c.size.x
		if left < -tolerance or right > view.x + tolerance:
			out.append("%s pos %.0f size %.0f x %.0f (view %.0f)" % [c.get_path(), left, c.size.x, c.size.y, view.x])
		var scroller: ScrollContainer = c as ScrollContainer
		if scroller != null and scroller.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return  # its own rect was checked above; its children are meant to extend
	for child: Node in node.get_children():
		_walk(child, view, tolerance, out)


## The Controls below `root` whose own minimum width is more than `limit` (the viewport minus the screen's margins), deepest first: the
## leaf-most ones are the culprits (a label that cannot wrap, a row that cannot shrink); their parents only add them up.
static func wide_minimums(root: Control, limit: float, count: int = 8) -> Array[String]:
	var found: Array[Dictionary] = []
	_collect_min(root, limit, 0, found)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = a["depth"]
		var db: int = b["depth"]
		return da > db)
	var out: Array[String] = []
	for entry: Dictionary in found.slice(0, count):
		out.append(str(entry["text"]))
	return out


static func _collect_min(node: Node, limit: float, depth: int, out: Array[Dictionary]) -> void:
	var c: Control = node as Control
	if c != null and c.visible:
		var need: float = c.get_combined_minimum_size().x
		if need > limit:
			out.append({"depth": depth, "text": "%s min %.0f" % [c.get_path(), need]})
	for child: Node in node.get_children():
		_collect_min(child, limit, depth + 1, out)
