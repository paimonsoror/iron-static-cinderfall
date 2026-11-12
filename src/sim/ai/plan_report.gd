class_name PlanReport
extends RefCounted
## A RunPlan as text (VARIETY_SPEC 13.8 `plan_dump`): the bosses, both options of every wave with their groups and
## elites, the events, the drum points, then one summary line with a hash of the whole plan. It reads the plan and the
## content only, so two runs of one seed print the same bytes; tools/plan_dump.gd prints it and the tests feed it
## hand-made plans.

## Why a plan cannot be printed while RunPlanSystem.build still returns the stub of the scaffold.
const STUB_MESSAGE: String = (
	"the run plan is still the legacy stub (RunPlanSystem.build returns RunPlan.from_legacy: no bosses, one fixed option"
	+ " per wave); the generated plan comes with task V2-A"
)


## The scaffold's plan: scripted waves as one-option waves, no boss ids (a generated plan always has one per act).
static func is_legacy_stub(plan: RunPlan) -> bool:
	return plan == null or plan.boss_ids.is_empty()


## Every line, in order; the last one starts with "PLAN SUMMARY:".
static func lines(plan: RunPlan, content: ContentSet, run_seed: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var option_total: int = 0
	var event_total: int = 0
	out.append("PLAN seed=%d waves=%d acts=%d" % [run_seed, plan.wave_count(), content.run.acts.size()])
	for act_index: int in plan.boss_ids.size():
		out.append("PLAN boss act=%d enemy=%s" % [act_index + 1, _enemy_id(content, plan.boss_ids[act_index])])
	out.append("PLAN boss_variant=%s" % _variant_id(content, plan.boss_variant))
	for w: PlannedWave in plan.waves:
		out.append(
			"PLAN wave=%d act=%d kind=%s options=%d events=%d" % [w.index, w.act, _kind(content, w), w.options.size(), w.events.size()]
		)
		for o: int in w.options.size():
			option_total += 1
			out.append_array(_option_lines(content, w.options[o], o))
		for e: PlannedEvent in w.events:
			event_total += 1
			out.append("PLAN   event=%s at_tick=%d" % [_event_id(content, e.event_index), e.start_offset])
	out.append("PLAN drums points=%s" % ",".join(_ints(plan.drum_points)))
	var h: StateHasher = StateHasher.new()
	plan.hash_into(h)
	out.append(
		"PLAN SUMMARY: seed=%d waves=%d options=%d events=%d plan_hash=%s" % [run_seed, plan.wave_count(), option_total, event_total, h.finish()]
	)
	return out


static func _option_lines(content: ContentSet, o: RouteOption, position: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append(
		"PLAN   option=%s pack=%s modifier=%s reward=%s hot=%d bodies=%d elites=%d"
		% [
			"AB".substr(position, 1) if position < 2 else str(position),
			_pack_id(content, o.pack_index),
			_modifier_id(content, o.modifier_index),
			_reward_id(content, o.reward_index),
			1 if o.hot else 0,
			o.total_count(),
			o.elites.size(),
		]
	)
	for g: SpawnGroupDef in o.groups:
		out.append(
			"PLAN     group enemy=%s count=%d start_tick=%d interval_ticks=%d region=%s"
			% [_enemy_id(content, g.enemy_index), g.count, g.start_tick, g.interval_ticks, String(g.region_id)]
		)
	for e: PlannedElite in o.elites:
		out.append("PLAN     elite group=%d ordinal=%d affixes=%s" % [e.group, e.ordinal, _affixes(content, e.affix_mask)])
	return out


static func _kind(content: ContentSet, w: PlannedWave) -> String:
	var slot: WaveSlotDef = content.run.wave_slot(w.index)
	if slot != null and slot.kind >= 0 and slot.kind < WaveSlotDef.KIND_NAMES.size():
		return WaveSlotDef.KIND_NAMES[slot.kind]
	return "boss" if w.is_boss else "normal"


static func _enemy_id(content: ContentSet, index: int) -> String:
	return String(content.enemies[index].id) if index >= 0 and index < content.enemies.size() else "?%d" % index


static func _variant_id(content: ContentSet, index: int) -> String:
	var variants: Array[StringName] = content.run.hulk_variants
	return String(variants[index]) if index >= 0 and index < variants.size() else "-"


static func _pack_id(content: ContentSet, index: int) -> String:
	return String(content.run.packs[index].id) if index >= 0 and index < content.run.packs.size() else "-"


static func _modifier_id(content: ContentSet, index: int) -> String:
	return String(content.run.modifiers[index].id) if index >= 0 and index < content.run.modifiers.size() else "-"


static func _reward_id(content: ContentSet, index: int) -> String:
	return String(content.run.route_rewards[index].id) if index >= 0 and index < content.run.route_rewards.size() else "-"


static func _event_id(content: ContentSet, index: int) -> String:
	return String(content.events[index].id) if index >= 0 and index < content.events.size() else "?%d" % index


## Names of the affixes whose bits are set in `mask`, joined with "+"; "-" for none.
static func _affixes(content: ContentSet, mask: int) -> String:
	var names: PackedStringArray = PackedStringArray()
	for a: AffixDef in content.affixes:
		if mask & (1 << a.index) != 0:
			names.append(String(a.id))
	return "+".join(names) if not names.is_empty() else "-"


static func _ints(values: PackedInt32Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for v: int in values:
		out.append(str(v))
	return out
