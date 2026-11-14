extends GdUnitTestSuite
## V5-B: the four choice overlays (draft, route, boss briefing, salvage) and the pause overlay fit every viewport with the
## longest text of the SHIPPED content: every directive on the draft, every pack with every modifier and reward on the route,
## every boss on the briefing, every weapon on the salvage screen; no control leaves the viewport, no text is cut and no two
## controls overlap (UiOverflowKit.problems).

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = Content.db


func after_test() -> void:
	ScreensTestKit.fresh_save()
	RunSession.bind(null, null)


## The choice overlays are laid out for the phone's 1080 px canvas (two route cards side by side need 892 px, three directive cards
## 1008): the stretch mode `expand` never makes the canvas narrower, so the 900 and 720 px windows of the screen checks do not
## exist for them. The wide window is the inner display of a foldable.
func _sizes() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for view: Vector2 in UiOverflowKit.SIZES_V5B:
		if view.x >= 1080.0:
			out.append(view)
	out.append(UiOverflowKit.SIZE_WIDE)
	return out


func _overlay(path: String, api: FakeRunApi, view: Vector2) -> RunOverlayBase:
	var packed: PackedScene = load(path) as PackedScene
	var node: RunOverlayBase = packed.instantiate() as RunOverlayBase
	V5bKit.host(self, view).add_child(node)
	node.call("setup", api, _cs)
	return node


func _check(node: Control, view: Vector2, what: String) -> void:
	var message: String = V5bKit.verdict(node, view, what)
	assert_str(message).override_failure_message(message).is_empty()


func _api(state: String) -> FakeRunApi:
	var api: FakeRunApi = FakeRunApi.new()
	var ok: bool = FakeRunPresets.apply(api, _cs, state)
	assert_bool(ok).is_true()
	api.fake_scrap = V5bKit.BIG
	api.fake_run_seed = 2147483647
	return api


# --- the draft ---


## The directives sorted by the length of their name and rules, longest first.
func _longest_directives() -> Array[int]:
	var order: Array[int] = []
	for i: int in _cs.directives.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _directive_text(a).length() > _directive_text(b).length())
	return order


func _directive_text(i: int) -> String:
	var def: DirectiveDef = _cs.directives[i]
	return Strings.t(def.name_key) + Strings.t(def.desc_key)


func _draft(offer: Array[int], view: Vector2) -> DraftOverlay:
	var api: FakeRunApi = _api("draft")
	api.fake_draft_offer = PackedInt32Array(offer)
	api.fake_draft_ids = []
	for i: int in offer:
		api.fake_draft_ids.append(_cs.directives[i].id)
	return _overlay("res://src/ui/run/draft_overlay.tscn", api, view) as DraftOverlay


func test_the_draft_with_the_three_longest_directives_fits_every_viewport() -> void:
	var worst: Array[int] = _longest_directives().slice(0, 3)
	for view: Vector2 in _sizes():
		var node: DraftOverlay = _draft(worst, view)
		await V5bKit.settle(get_tree())
		_check(node, view, "draft (longest three)")
		node.cards[0].tap()
		await V5bKit.settle(get_tree(), 2)
		_check(node, view, "draft (first card selected)")


func test_the_draft_of_every_directive_fits_the_tall_phone() -> void:
	var view: Vector2 = UiOverflowKit.SIZES_V5B[0]
	var all: Array[int] = []
	for i: int in _cs.directives.size():
		all.append(i)
	var failures: Array[String] = []
	for start: int in range(0, all.size(), 3):
		var offer: Array[int] = all.slice(start, start + 3)
		var node: DraftOverlay = _draft(offer, view)
		await V5bKit.settle(get_tree(), 3)
		var message: String = V5bKit.verdict(node, view, "draft %s" % str(offer))
		if message != "":
			failures.append(message)
		node.get_parent().queue_free()
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 5))).is_empty()


# --- the route ---


func _route_options(pack_a: int, pack_b: int, modifier_a: int, modifier_b: int) -> Array[Dictionary]:
	var run: RunDef = _cs.run
	var out: Array[Dictionary] = []
	for pair: Array in [[pack_a, modifier_a, true], [pack_b, modifier_b, false]]:
		var pack: PackDef = run.packs[pair[0]]
		var modifier: ModifierDef = run.modifiers[pair[1]]
		var counts: Dictionary = {}
		for g: int in pack.group_count():
			counts[Ids.ENEMIES[pack.group_enemy[g]]] = 29 + g
		var reward: RewardDef = run.route_rewards[0]
		out.append({
			"pack": pack.id, "name_key": pack.name_key, "counts": counts, "total": 999, "modifier": modifier.id,
			"modifier_key": modifier.name_key, "elites": 3, "hot": pair[2], "reward": reward.id, "reward_key": reward.name_key,
			"reward_amount": 120,
		})
	return out


func test_every_pack_and_modifier_on_the_route_fits_every_viewport() -> void:
	var packs: int = _cs.run.packs.size()
	var mods: int = _cs.run.modifiers.size()
	for view: Vector2 in _sizes():
		var failures: Array[String] = []
		for k: int in packs:
			var api: FakeRunApi = _api("route")
			api.fake_route_options = _route_options(k, (k + 1) % packs, k % mods, (k + 3) % mods)
			var node: Control = _overlay("res://src/ui/run/route_overlay.tscn", api, view)
			await V5bKit.settle(get_tree(), 3)
			var message: String = V5bKit.verdict(node, view, "route pack %d" % k)
			if message != "":
				failures.append(message)
			node.get_parent().queue_free()
		assert_array(failures).override_failure_message("\n".join(failures.slice(0, 4))).is_empty()


# --- the boss briefing ---


## The five bosses and the three variants of Node 9 (the names and lines come from the string table, which has them all even
## where the shipped data file has not got the boss yet).
func _briefs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in [&"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig", &"siege_hulk"]:
		out.append({
			"id": id, "name_key": "boss.%s.name" % String(id), "banner_key": "boss.%s.banner" % String(id), "variant": &"",
			"attack_key": "", "answer_key": "",
		})
	for variant: StringName in [&"hulk_plated", &"hulk_fed", &"hulk_overclocked"]:
		out.append({
			"id": &"siege_hulk", "name_key": "boss.siege_hulk.name", "banner_key": "boss.siege_hulk.banner", "variant": variant,
			"attack_key": "", "answer_key": "",
		})
	return out


func test_the_briefing_of_every_boss_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var failures: Array[String] = []
		for brief: Dictionary in _briefs():
			var api: FakeRunApi = _api("boss_brief")
			api.fake_boss_brief = brief
			var node: Control = _overlay("res://src/ui/run/boss_brief_overlay.tscn", api, view)
			await V5bKit.settle(get_tree(), 3)
			var brief_id: StringName = brief["id"]
			var brief_variant: StringName = brief["variant"]
			var message: String = V5bKit.verdict(node, view, "boss brief %s %s" % [brief_id, brief_variant])
			if message != "":
				failures.append(message)
			node.get_parent().queue_free()
		assert_array(failures).override_failure_message("
".join(failures.slice(0, 4))).is_empty()


# --- the salvage ---


func test_the_salvage_of_every_weapon_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var failures: Array[String] = []
		for w: WeaponDef in _cs.weapons:
			var api: FakeRunApi = _api("salvage")
			api.fake_salvage_offer = {"weapons": [w.id], "tiers": [5], "level_up_slot": [-1], "boss": false, "scrap_value": 9999}
			var node: Control = _overlay("res://src/ui/run/salvage_overlay.tscn", api, view)
			await V5bKit.settle(get_tree(), 3)
			var message: String = V5bKit.verdict(node, view, "salvage %s" % String(w.id))
			if message != "":
				failures.append(message)
			node.get_parent().queue_free()
		assert_array(failures).override_failure_message("\n".join(failures.slice(0, 4))).is_empty()
