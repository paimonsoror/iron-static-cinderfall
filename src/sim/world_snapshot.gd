class_name WorldSnapshot
extends RefCounted
## The boundary snapshot of resume (VARIETY_SPEC 2.8 option D, 13.3 `boundary.state`): the state of a world at a wave
## clear as a JSON-safe Dictionary, and its way back. At a boundary the world has no enemies, hazards or pending
## spawns, so the document is small. `SimWorld.state_hash()` after `restore` must equal the hash before `capture`.
# TODO(V2-D): the variety state classes are captured and restored here already; the frozen stores (turrets, warden,
# abilities), the scalars of SimWorld, PhaseState, CombatState, NavState, the RNG stream states, RunStats and the
# seen command ids are still missing, so `restore` returns false until they are added.

const VERSION: int = 1


static func capture(world: SimWorld) -> Dictionary:
	return {
		"version": VERSION,
		"tick": world.tick,
		"wave": world.wave,
		"plan": world.plan.to_dict() if world.plan != null else {},
		"mods": world.mods.to_dict(),
		"arsenal": world.arsenal.to_dict(),
		"draft": world.draft.to_dict(),
		"salvage": world.salvage.to_dict(),
		"ext": world.ext.to_dict(),
		"hazards": world.hazards.to_dict(),
		"events_state": world.events_state.to_dict(),
		"boss": world.boss.to_dict(),
	}


## Applies `doc` to a fresh world built from the same SimConfig. True when the whole state was restored.
static func restore(world: SimWorld, doc: Dictionary) -> bool:
	if roundi(SnapUtil.num(doc.get("version", 0))) != VERSION:
		return false
	var plan_doc: Dictionary = doc.get("plan", {})
	if not plan_doc.is_empty():
		world.plan = RunPlan.from_dict(plan_doc)
	_apply(world.mods, doc, "mods")
	_apply(world.arsenal, doc, "arsenal")
	_apply(world.draft, doc, "draft")
	_apply(world.salvage, doc, "salvage")
	_apply(world.ext, doc, "ext")
	_apply(world.hazards, doc, "hazards")
	_apply(world.events_state, doc, "events_state")
	_apply(world.boss, doc, "boss")
	return false


static func _apply(state: Object, doc: Dictionary, key: String) -> void:
	var part: Variant = doc.get(key)
	if typeof(part) == TYPE_DICTIONARY:
		state.call("from_dict", part)
