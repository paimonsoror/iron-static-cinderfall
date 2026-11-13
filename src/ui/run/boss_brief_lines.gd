class_name BossBriefLines
extends RefCounted
## The ATTACK and ANSWER lines of the boss briefing (VARIETY_SPEC 11.2). The approved lines stay exactly as written; the
## ANSWER line may only name answers the run can have (V3-I carry-over): when it names a weapon that an Archive unlock gates and
## this profile has not bought, the briefing shows the line's `.open` variant instead (the same advice without the weapon,
## `boss.<id>.answer.open`), and the approved line when no variant exists. The weapons a profile can field are the base
## weapons (no unlock grants them) plus those of the unlocks it owns.


## The first of the variant's, the brief's and the boss's own line that exists, or "". `kind` is "attack" or "answer".
static func line(brief: Dictionary, kind: String, content: ContentSet) -> String:
	var key: String = line_key(brief, kind)
	if key == "":
		return ""
	if kind == "answer":
		var open_key: String = key + ".open"
		if RunUi.has_key(open_key) and not unowned_weapons_named(Strings.t(key), content).is_empty():
			return Strings.t(open_key)
	return Strings.t(key)


## The string key of the line, or "".
static func line_key(brief: Dictionary, kind: String) -> String:
	var keys: Array[String] = []
	var variant: StringName = brief.get("variant", &"")
	if variant != &"":
		keys.append("boss.%s.%s" % [String(variant), kind])
	var given: String = brief.get("%s_key" % kind, "")
	if given != "":
		keys.append(given)
	var boss_id: StringName = brief.get("id", &"")
	keys.append("boss.%s.%s" % [String(boss_id), kind])
	for key: String in keys:
		if RunUi.has_key(key):
			return key
	return ""


## The weapons that an unlock gates and this profile has not bought ("u_w_arc" owned = arc_projector is fielded).
static func unowned_weapons(content: ContentSet) -> Array[StringName]:
	var out: Array[StringName] = []
	if content == null:
		return out
	for unlock: UnlockDef in content.unlocks:
		if Save.has_unlock(unlock.id):
			continue
		for granted: StringName in unlock.grants:
			if content.weapon(granted) != null and not out.has(granted):
				out.append(granted)
	return out


## The weapons of `unowned_weapons` that `text` names (by weapon name or short name, whole words, any case).
static func unowned_weapons_named(text: String, content: ContentSet) -> Array[StringName]:
	var named: Array[StringName] = []
	var lowered: String = text.to_lower()
	for id: StringName in unowned_weapons(content):
		for key: String in ["weapon.%s.name" % String(id), "weapon.%s.short" % String(id)]:
			if RunUi.has_key(key) and _has_word(lowered, Strings.t(key).to_lower()) and not named.has(id):
				named.append(id)
	return named


static func _has_word(lowered_text: String, word: String) -> bool:
	if word == "":
		return false
	var at: int = lowered_text.find(word)
	while at >= 0:
		var before_ok: bool = at == 0 or not _is_letter(lowered_text[at - 1])
		var end: int = at + word.length()
		var after_ok: bool = end >= lowered_text.length() or not _is_letter(lowered_text[end])
		if before_ok and after_ok:
			return true
		at = lowered_text.find(word, at + 1)
	return false


static func _is_letter(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "0" and c <= "9")
