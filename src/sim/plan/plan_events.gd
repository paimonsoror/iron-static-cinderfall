class_name PlanEvents
extends RefCounted
## The world events of a planned wave (VARIETY_SPEC 7, CONTENT 6 "Schedule rules"). Rolled at tick 0 from the stream
## `plan.event:<w>`. Rules applied here: only world events whose weight for the act is above zero; a boss wave takes
## boss-safe events only; the same event never appears in two consecutive waves; static front and power surge never
## share a wave (so they never overlap); at most one harmful event per wave in acts I and II; wave 3 is always helpful.
## Times are drawn uniformly in the rules' window (25 to 70 percent of the wave window) and are the start of the WARNING.

const HELPFUL_ONLY_WAVE: int = 3
const NEVER_TOGETHER_A: StringName = &"static_front"
const NEVER_TOGETHER_B: StringName = &"power_surge"


## The events of one wave, sorted by start offset. `previous` are the EventDef indices planned for the wave before.
## Per slot the stream gives two draws (the event, then its time), whether or not an event is found.
static func roll(
	content: ContentSet, slot: WaveSlotDef, previous: PackedInt32Array, stream: RandomNumberGenerator
) -> Array[PlannedEvent]:
	var out: Array[PlannedEvent] = []
	var run: RunDef = content.run
	var harmful: int = 0
	for _slot: int in slot.event_slots:
		var weights: PackedFloat64Array = PackedFloat64Array()
		for e: EventDef in content.events:
			weights.append(_weight(content, slot, e, out, previous, harmful))
		var pick: int = PlanRng.weighted(stream, weights)
		var moment: float = PlanRng.unit(stream)
		if pick < 0:
			continue
		var planned: PlannedEvent = PlannedEvent.new()
		planned.event_index = pick
		planned.start_offset = roundi(lerpf(run.event_window_min, run.event_window_max, moment) * float(slot.window_ticks))
		out.append(planned)
		if content.events[pick].harmful:
			harmful += 1
	for a: int in range(1, out.size()):
		var moving: PlannedEvent = out[a]
		var b: int = a - 1
		while b >= 0 and out[b].start_offset > moving.start_offset:
			out[b + 1] = out[b]
			b -= 1
		out[b + 1] = moving
	return out


## The EventDef indices of `events`, for the next wave's `previous`.
static func indices(events: Array[PlannedEvent]) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: PlannedEvent in events:
		out.append(e.event_index)
	return out


static func _weight(
	content: ContentSet,
	slot: WaveSlotDef,
	e: EventDef,
	chosen: Array[PlannedEvent],
	previous: PackedInt32Array,
	harmful: int
) -> float:
	if e.who != EventDef.Who.WORLD or slot.act - 1 >= e.weights.size():
		return 0.0
	var w: float = e.weights[slot.act - 1]
	if not w > 0.0 or previous.has(e.index):
		return 0.0
	if slot.kind == WaveSlotDef.Kind.BOSS and not e.boss_safe:
		return 0.0
	if e.harmful and (slot.index == HELPFUL_ONLY_WAVE or (slot.act <= 2 and harmful >= 1)):
		return 0.0
	for p: PlannedEvent in chosen:
		if p.event_index == e.index:
			return 0.0
		var other: StringName = content.events[p.event_index].id
		if (e.id == NEVER_TOGETHER_A and other == NEVER_TOGETHER_B) or (e.id == NEVER_TOGETHER_B and other == NEVER_TOGETHER_A):
			return 0.0
	return w
