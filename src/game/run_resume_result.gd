class_name RunResumeResult
extends RefCounted
## What RunResume.rebuild made of a run file.

var mode: int = RunResume.Mode.FAILED
var world: SimWorld  ## the rebuilt world at the resume tick; null when the mode is FAILED
var config: SimConfig
var run_id: String = ""
var reason: String = ""  ## why the snapshot path or the whole rebuild failed (for the log)


func ok() -> bool:
	return mode != RunResume.Mode.FAILED and world != null
