class_name RunPlanSystem
extends RefCounted
## Builds the run plan at tick 0 (VARIETY_SPEC 9.3): bosses from `plan.boss`, both options of every normal wave from
## `plan.route:<w>` and `plan.wave:<w>:<o>`, elites from `plan.elite:<w>`, events from `plan.event:<w>`, drum points
## from `plan.hazard:<act>`. Called once by SimWorld._init, after every state class exists.
# TODO(V2-A): generate the plan from content.run. The stub draws from no stream.


## Null for the legacy content (no plan: SpawnSystem reads content.waves). For variety content the stub returns the
## legacy scripted waves as a one-option plan, so the tuned 5-wave run still plays until V2-A lands.
static func build(world: SimWorld) -> RunPlan:
	if not world.content.is_variety():
		return null
	return RunPlan.from_legacy(world.content.waves)


## Patches the remaining waves for a directive that changes the future (chorus_handshake, static_pact, open_gate),
## with the stream `plan.patch:<directive>:<w>`.
static func patch(_world: SimWorld, _directive_index: int) -> void:
	pass
