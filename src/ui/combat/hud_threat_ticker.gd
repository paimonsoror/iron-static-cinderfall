class_name HudThreatTicker
extends VBoxContainer
## The threat ticker under the top bar (VARIETY_SPEC 11.4, 7.2): up to three lines of icon + text + countdown bar. It owns all
## event text. A warning line counts toward the effect ("STATIC FRONT IN 6 s", the bar fills), a running line counts down
## ("RELAY WINDOW  8 s", the bar drains). Harmful events are red with a warning triangle, helpful ones cyan with a hex mark:
## shape and word, never color alone. Short notices (an elite entering) share the lines. Under High Contrast the text has
## the dark outline of every HUD label. Information only: it takes no taps.

const MAX_LINES: int = 3
const NOTICE_SECONDS: float = 4.0
const PRIO_WARN_HARMFUL: int = 0
const PRIO_CRATE_CONTESTED: int = 1
const PRIO_CRATE: int = 2
const PRIO_RUN_HARMFUL: int = 3
const PRIO_WARN_HELPFUL: int = 4
const PRIO_RUN_HELPFUL: int = 5
const PRIO_NOTICE: int = 6

var lines: Array[HudTickerLine] = []
var _notices: Array[Dictionary] = []  ## { "text": String, "harmful": bool, "left": float }


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 6)
	for i: int in MAX_LINES:
		var line: HudTickerLine = HudTickerLine.new()
		line.visible = false
		add_child(line)
		lines.append(line)


## Re-reads the events that are warning or running (RunApi.active_events) and shows the first MAX_LINES lines by priority:
## a harmful event that is about to start, a contested crate, a crate in the clear, a harmful event that is running, a helpful
## event about to start, a helpful event running, then the short notices. Within one priority the older line stays first.
## `crate` is RunApi.crate_status(): a crate on the field is "ACCORD DROP  7 s" with the bar filling while the area is clear,
## "DROP CONTESTED" (red, the bar frozen) while an enemy stands on it.
func refresh(events: Array[Dictionary], content: ContentSet, crate: Dictionary = {}) -> void:
	var candidates: Array[Dictionary] = []  # { "prio": int, "text": String, "harmful": bool, "fraction": float }
	if not crate.is_empty():
		var crate_left: int = crate.get("ticks_left", 0)
		var crate_all: int = crate.get("ticks_total", 1)
		var crate_total: int = maxi(crate_all, 1)
		var contested: bool = crate.get("contested", false)
		var crate_text: String = Strings.tf("hud.ticker.on", [event_name(&"supply_drop", content), HudStyle.secs(crate_left)])
		candidates.append({
			"prio": PRIO_CRATE_CONTESTED if contested else PRIO_CRATE,
			"text": Strings.t("hud.crate.contested") if contested else crate_text,
			"harmful": contested, "fraction": 1.0 - float(crate_left) / float(crate_total),
		})
	for e: Dictionary in events:
		var id: StringName = e.get("id", &"")
		var phase: int = e.get("phase", 0)
		var left: int = e.get("ticks_left", 0)
		var total_ticks: int = e.get("ticks_total", 1)
		var total: int = maxi(total_ticks, 1)
		var harmful: bool = e.get("harmful", false)
		var secs: int = HudStyle.secs(left)
		var title: String = event_name(id, content)
		candidates.append({
			"prio": priority_of(phase == 0, harmful),
			"text": Strings.tf("hud.ticker.in", [title, secs]) if phase == 0 else Strings.tf("hud.ticker.on", [title, secs]),
			"harmful": harmful,
			"fraction": 1.0 - float(left) / float(total) if phase == 0 else float(left) / float(total),
		})
	for n: Dictionary in _notices:
		candidates.append({"prio": PRIO_NOTICE, "text": n.get("text", ""), "harmful": n.get("harmful", false), "fraction": -1.0})
	var ordered: Array[Dictionary] = []
	for rank: int in PRIO_NOTICE + 1:  # a stable order: by priority, then as given
		for c: Dictionary in candidates:
			if c["prio"] == rank:
				ordered.append(c)
	var shown: int = 0
	for c: Dictionary in ordered:
		if shown >= MAX_LINES:
			break
		var text: String = c["text"]
		var harmful_line: bool = c["harmful"]
		var fraction: float = c["fraction"]
		lines[shown].show_line(text, harmful_line, fraction)
		shown += 1
	for i: int in range(shown, MAX_LINES):
		lines[i].visible = false


## The priority of an event line (lower shows first): `warning` = it has not started yet.
static func priority_of(warning: bool, harmful: bool) -> int:
	if warning:
		return PRIO_WARN_HARMFUL if harmful else PRIO_WARN_HELPFUL
	return PRIO_RUN_HARMFUL if harmful else PRIO_RUN_HELPFUL


## The count of lines on screen.
func visible_lines() -> int:
	var n: int = 0
	for line: HudTickerLine in lines:
		if line.visible:
			n += 1
	return n


## A timed one-line notice (an elite entering the field).
func push_notice(text: String, harmful: bool = true) -> void:
	_notices.append({"text": text, "harmful": harmful, "left": NOTICE_SECONDS})
	while _notices.size() > MAX_LINES:
		_notices.pop_front()


## Counts the notices down; true when one expired (the caller redraws the lines).
func tick(delta: float) -> bool:
	var expired: bool = false
	for i: int in range(_notices.size() - 1, -1, -1):
		var left: float = _notices[i]["left"]
		left -= delta
		_notices[i]["left"] = left
		if left <= 0.0:
			_notices.remove_at(i)
			expired = true
	return expired


## "STATIC FRONT": the EventDef's name string, else the id in capitals.
static func event_name(id: StringName, content: ContentSet) -> String:
	var def: EventDef = content.event_def(id) if content != null else null
	if def != null and RunUi.has_key(def.name_key):
		return Strings.t(def.name_key)
	return RunUi.opt("event.%s.name" % String(id), String(id).replace("_", " ").to_upper())
