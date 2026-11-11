class_name SimRunApi
extends RunApi
## RunApi bound to a RunController. TODO(W2-A). The stub keeps the base-class defaults.

@warning_ignore_start("unused_parameter")

var controller: RunController


func bind(run_controller: RunController) -> void:
	# TODO(W2-A)
	controller = run_controller
