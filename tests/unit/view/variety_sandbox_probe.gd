class_name VarietySandboxProbe
extends RefCounted
## Test helper (V1-S): reaches the static handshake of src/debug/view_sandbox.gd (the script has no class_name).


static func draws_variety(view: BattleView) -> bool:
	var script: Script = load("res://src/debug/view_sandbox.gd") as Script
	var answer: Variant = script.call("view_draws_variety", view)
	var out: bool = answer
	return out
