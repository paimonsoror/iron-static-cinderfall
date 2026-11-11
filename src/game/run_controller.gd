class_name RunController
extends Node
## Owns one run: ticks the sim, drains its events into Events, renders the view. TODO(W2-A).

@warning_ignore_start("unused_parameter")

var sim: SimWorld
var api: SimRunApi
var run_id: String
var paused: bool = false
var bot: PolicyBot = null  ## set by --autoplay


func start(config: SimConfig, run_id_value: String, view: BattleView) -> void:
	# TODO(W2-A)
	run_id = run_id_value


func set_paused(value: bool) -> void:
	# TODO(W2-A)
	paused = value


## Unbinds the view, frees the sim.
func stop() -> void:
	# TODO(W2-A)
	pass


## If not paused: driver.advance; drain events -> Events; view.render(alpha).
func _process(delta: float) -> void:
	# TODO(W2-A)
	pass
