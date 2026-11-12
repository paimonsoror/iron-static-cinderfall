class_name BuildSignature
extends RefCounted
## The build signature of a run (VARIETY_SPEC 14.2 S11): the primary weapon (most damage dealt) plus the two tags with
## the most stacks, e.g. "arc_projector+arc+tempo". Used by the scorecard and printed by tools/sim_run.
# TODO(V2-H)


static func of(_world: SimWorld) -> String:
	return ""
