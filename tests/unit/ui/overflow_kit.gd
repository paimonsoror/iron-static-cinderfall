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
		var box: Rect2 = rect_of(c)
		var left: float = box.position.x
		var right: float = box.end.x
		if left < -tolerance or right > view.x + tolerance:
			out.append("%s pos %.0f size %.0f x %.0f (view %.0f)" % [c.get_path(), left, box.size.x, box.size.y, view.x])
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


# --- V5-B: the same guard for every screen (vertical fit, cut text, overlapping controls) ---


## The six viewports of the V5-B guard: the Pixel's outer display, a tall and a very tall phone, a near-square window and two
## narrower ones (the canvas is never narrower than 1080 in the game: the stretch mode expands the height; the narrow ones are headroom).
const SIZES_V5B: Array[Vector2] = [
	Vector2(1080.0, 2342.0), Vector2(1080.0, 2400.0), Vector2(1080.0, 2640.0), Vector2(1080.0, 1120.0), Vector2(900.0, 2000.0),
	Vector2(720.0, 1600.0),
]
## A wide window (the inner display of the foldable: the viewport grows sideways, never narrower than 1080 x 1920 in height).
const SIZE_WIDE: Vector2 = Vector2(1853.0, 1920.0)
const MAX_ICON: float = 360.0  ## a TextureRect bigger than this is a backdrop, not content


## The rectangle `c` really covers in the viewport (its own scale counts: a selected card is lifted by 3.5%).
static func rect_of(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


## Visible Controls below `root` that leave the viewport sideways or at the bottom or top. Controls inside a ScrollContainer
## (which scrolls on its own) are skipped. `skip` names nodes to leave out (a hidden-by-design drawer, a full-screen backdrop).
static func leaving(root: Control, view: Vector2, skip: Array[Node] = [], tolerance: float = 0.5) -> Array[String]:
	var out: Array[String] = []
	_walk_all(root, view, tolerance, skip, out)
	return out


static func _walk_all(node: Node, view: Vector2, tolerance: float, skip: Array[Node], out: Array[String]) -> void:
	if skip.has(node):
		return
	var c: Control = node as Control
	if c != null:
		if not c.visible:
			return
		var box: Rect2 = rect_of(c)
		if box.position.x < -tolerance or box.end.x > view.x + tolerance or box.position.y < -tolerance or box.end.y > view.y + tolerance:
			out.append("%s rect %s (view %s)" % [c.get_path(), box, view])
		if c is ScrollContainer:
			return  # its children scroll
	for child: Node in node.get_children():
		_walk_all(child, view, tolerance, skip, out)


## Visible single-line Labels and plain Buttons below `root` whose text is wider than their box: the text is cut ("FREIGH") or
## trimmed with an ellipsis. Wrapping labels are not asked (they grow downward).
static func cut_text(root: Node, tolerance: float = 1.5) -> Array[String]:
	var out: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var c: Control = node as Control
		if c != null and not c.is_visible_in_tree():
			continue
		var label: Label = node as Label
		if label != null and label.text.strip_edges() != "" and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var need: float = text_width(label)
			if need > label.size.x + tolerance:
				out.append("%s '%s' needs %.0f has %.0f" % [label.get_path(), label.text.replace("\n", "|"), need, label.size.x])
		var button: Button = node as Button
		if button != null and button.text.strip_edges() != "" and not button.text.begins_with("#"):
			var font: Font = button.get_theme_font(&"font")
			var px: int = button.get_theme_font_size(&"font_size")
			var inner: float = button.size.x - button.get_theme_stylebox(&"normal").get_minimum_size().x
			# a wrapping button breaks between words: what must fit is its longest word ("DIRECTIV" over "ES" is a split word)
			var need_b: float = _widest_line(font, button.text, px) if button.autowrap_mode == TextServer.AUTOWRAP_OFF else _longest_word(font, button.text, px)
			if need_b > inner + tolerance:
				out.append("%s '%s' needs %.0f has %.0f" % [button.get_path(), button.text.replace("\n", "|"), need_b, inner])
		for child: Node in node.get_children():
			stack.append(child)
	return out


## The width of the widest line of `label`'s text in its font and size.
static func text_width(label: Label) -> float:
	var font: Font = label.get_theme_font(&"font")
	var px: int = label.get_theme_font_size(&"font_size")
	return _widest_line(font, label.text, px)


static func _longest_word(font: Font, text: String, px: int) -> float:
	var best: float = 0.0
	for word: String in text.replace("
", " ").split(" ", false):
		best = maxf(best, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x)
	return best


static func _widest_line(font: Font, text: String, px: int) -> float:
	var best: float = 0.0
	for line: String in text.split("\n"):
		best = maxf(best, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x)
	return best


## Pairs of visible content controls (text labels, icons, buttons) below `root` whose boxes cross by more than `min_px` in both
## directions and where neither contains the other as a child. A label counts by its text, not by its (often wider) box.
## Returns "pathA x pathB (overlap w x h)". Content that is deliberately layered (a scrim, a bar fill) is not a Control of these
## kinds, so it is not asked.
static func overlapping(root: Control, min_px: float = 4.0, skip: Array[Node] = []) -> Array[String]:
	var boxes: Array[Dictionary] = []
	var area: float = rect_of(root).get_area()
	_collect_content(root, skip, Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6), area, boxes)
	var out: Array[String] = []
	for i: int in boxes.size():
		for j: int in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			var na: Control = a["node"]
			var nb: Control = b["node"]
			if na.is_ancestor_of(nb) or nb.is_ancestor_of(na):
				continue
			if na is TextureRect and nb is TextureRect:
				continue  # icons are layered on purpose (a mark over its plate)
			var ra: Rect2 = a["rect"]
			var rb: Rect2 = b["rect"]
			var hit: Rect2 = ra.intersection(rb)
			if hit.size.x > min_px and hit.size.y > min_px:
				out.append("%s x %s (overlap %.0f x %.0f)" % [na.get_path(), nb.get_path(), hit.size.x, hit.size.y])
	return out


## `clip` is what the ancestors that clip their children (a ScrollContainer, a clip_contents panel) leave visible: the part of
## a scrolled row that is hidden behind the footer is not an overlap.
static func _collect_content(node: Node, skip: Array[Node], clip: Rect2, area: float, out: Array[Dictionary]) -> void:
	if skip.has(node):
		return
	var here: Rect2 = clip
	var c: Control = node as Control
	if c != null:
		if not c.visible:
			return
		if c is ScrollContainer or c.clip_contents:
			here = clip.intersection(rect_of(c))
		var cover: ColorRect = c as ColorRect
		if cover != null and cover.color.a >= 0.9 and rect_of(cover).get_area() >= 0.9 * area:
			out.clear()  # an opaque dim over the whole screen (a modal): what was drawn before it is hidden
		var label: Label = c as Label
		var box: Rect2 = Rect2()
		var content: bool = false
		if label != null and label.text.strip_edges() != "":
			box = _ink(label)
			content = true
		elif c is Button or c is RunSelectable:
			box = rect_of(c)
			content = true
		elif c is TextureRect and (c as TextureRect).texture != null and c.modulate.a > 0.05:
			box = rect_of(c)
			content = box.size.x <= MAX_ICON and box.size.y <= MAX_ICON  # a scrim or a backdrop is not an icon
		if content:
			var seen: Rect2 = box.intersection(clip)
			if seen.size.x > 0.0 and seen.size.y > 0.0:
				out.append({"node": c, "rect": seen})
	for child: Node in node.get_children():
		_collect_content(child, skip, here, area, out)


## The part of a label's box its text really inks: the widest line by the lines' height, placed by the alignment.
static func _ink(label: Label) -> Rect2:
	var box: Rect2 = rect_of(label)
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return box
	var font: Font = label.get_theme_font(&"font")
	var px: int = label.get_theme_font_size(&"font_size")
	var lines: int = label.text.split("\n").size()
	var w: float = minf(_widest_line(font, label.text, px), box.size.x)
	var h: float = minf(font.get_height(px) * float(lines), box.size.y)
	var x: float = box.position.x
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (box.size.x - w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += box.size.x - w
	var y: float = box.position.y
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y += (box.size.y - h) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			y += box.size.y - h
	return Rect2(x, y, w, h)


## Everything the guard asks, as one list: sideways and vertical escapes, cut text and overlaps.
static func problems(root: Control, view: Vector2, skip: Array[Node] = []) -> Array[String]:
	var out: Array[String] = []
	for line: String in leaving(root, view, skip):
		out.append("OUT " + line)
	for line: String in cut_text(root):
		out.append("CUT " + line)
	for line: String in overlapping(root, 4.0, skip):
		out.append("OVERLAP " + line)
	return out
