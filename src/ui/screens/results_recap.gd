class_name ResultsRecap
extends RefCounted
## The additions of the results screen of a generated run (GDD 10.6, VARIETY_SPEC 11.5): what broke the line (the harmful events
## that came and the machines that did the most damage to the core), the build recap (tags held, weapons, every directive with
## its stacks), the milestone line and the Archive hook that sells the next run. Each builder reads the RunSummary and the
## content only, and returns the text or the panel; the screen puts them in its column.

const MAX_BROKE: int = 3
const MAX_EVENTS: int = 2
const MAX_CHIPS: int = 4


# --- what broke the line ---


## The harmful events that started, most often first, at most MAX_EVENTS: their names in capitals.
static func events_line(summary: RunSummary, content: ContentSet) -> String:
	var names: Array[String] = []
	var pairs: Array[Vector2i] = []
	for i: int in mini(summary.events_seen.size(), content.events.size()):
		if summary.events_seen[i] > 0 and content.events[i].harmful:
			pairs.append(Vector2i(summary.events_seen[i], i))
	pairs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y))
	for pair: Vector2i in pairs.slice(0, MAX_EVENTS):
		names.append(HudThreatTicker.event_name(content.events[pair.y].id, content))
	return " + ".join(names)


## The machines that took the most core hit points, as ["spitter 412", ...] (lowercase names, at most MAX_BROKE).
static func damage_lines(summary: RunSummary, content: ContentSet) -> Array[String]:
	var pairs: Array[Vector2i] = []
	for i: int in mini(summary.core_damage_by_type.size(), content.enemies.size()):
		var hp: int = roundi(summary.core_damage_by_type[i])
		if hp > 0:
			pairs.append(Vector2i(hp, i))
	pairs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y))
	var out: Array[String] = []
	for pair: Vector2i in pairs.slice(0, MAX_BROKE):
		out.append(Strings.tf("results.broke_item", [Strings.t(content.enemies[pair.y].name_key).to_lower(), UiKit.group(pair.x)]))
	return out


# --- the build ---


## The tag glyph stacks of a build: tag -> stacks held (a directive of several tags counts for each).
static func tag_stacks(summary: RunSummary, content: ContentSet) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for i: int in mini(summary.directives.size(), content.directives.size()):
		var stacks: int = summary.directives[i]
		if stacks <= 0:
			continue
		for tag: StringName in content.directives[i].tags:
			var held: int = out.get(tag, 0)
			out[tag] = held + stacks
	return out


## The tags by stacks, most first (ties by name), at most MAX_CHIPS: ["ARC x4", "TEMPO x2"].
static func chip_texts(summary: RunSummary, content: ContentSet) -> Array[String]:
	var stacks: Dictionary[StringName, int] = tag_stacks(summary, content)
	var tags: Array[StringName] = []
	for tag: StringName in stacks.keys():
		tags.append(tag)
	tags.sort_custom(func(a: StringName, b: StringName) -> bool: return stacks[a] > stacks[b] or (stacks[a] == stacks[b] and String(a) < String(b)))
	var out: Array[String] = []
	for tag: StringName in tags.slice(0, MAX_CHIPS):
		out.append("%s %s" % [RunUi.tag_name(tag), Strings.tf("build.stacks", [stacks[tag]])])
	return out


## Every directive held with its stacks, in content order: ["HOT LOADS x2", ...].
static func directive_texts(summary: RunSummary, content: ContentSet) -> Array[String]:
	var out: Array[String] = []
	for i: int in mini(summary.directives.size(), content.directives.size()):
		var stacks: int = summary.directives[i]
		if stacks > 0:
			out.append("%s %s" % [Strings.t(content.directives[i].name_key), Strings.tf("build.stacks", [stacks])])
	return out


## The weapons at the end of the run: "ARC PROJ.  PISTOL" (short names, slot order).
static func weapons_line(summary: RunSummary, content: ContentSet) -> String:
	var names: PackedStringArray = PackedStringArray()
	for index: int in summary.weapons:
		if index >= 0 and index < content.weapons.size():
			names.append(WeaponStats.short_name(content.weapons[index].id))
	return "  ".join(names)


# --- milestones and the Archive hook ---


## "MILESTONE: NODE 9 FIRST KILL  +50" for a milestone `{ "id": StringName, "data": int }`.
static func milestone_text(item: Dictionary) -> String:
	var id: String = str(item.get("id", ""))
	var key: String = "milestone.%s" % id
	var amount: int = 0
	var raw: Variant = item.get("data", 0)
	if typeof(raw) == TYPE_INT:
		amount = raw
	return Strings.tf("results.milestone", [RunUi.opt(key, id.to_upper().replace("_", " ")), UiKit.group(amount)])


## The one-more-run line: what the Data now covers in the Archive, else the nearest goal, else "".
static func hook_text(content: ContentSet, profile: Profile) -> String:
	if content == null or profile == null or content.unlocks.is_empty():
		return ""
	var model: ArchiveModel = ArchiveModel.new(content, ArchiveBank.new(profile, content))
	var best: UnlockDef = model.best_affordable()
	if best != null:
		return Strings.tf("results.hook_afford", [ArchiveModel.display_name(best), UiKit.group(best.cost)])
	var goal: UnlockDef = model.next_goal()
	if goal != null:
		return Strings.tf("results.hook_goal", [ArchiveModel.display_name(goal), UiKit.group(goal.cost - profile.data)])
	return ""
