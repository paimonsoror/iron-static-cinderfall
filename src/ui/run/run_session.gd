class_name RunSession
extends RefCounted
## The run the HUD is showing, for the UI parts that are created without being handed it (the pause overlay: ARCH 9 gives it
## `setup()` with no arguments, yet it shows the run's seed and a BUILD button). The combat HUD registers its RunApi and content
## when it is set up and lets go when it leaves the tree. Read-only for everyone else; there is one run at a time.

static var _api: RunApi = null
static var _content: ContentSet = null


static func bind(run_api: RunApi, run_content: ContentSet) -> void:
	_api = run_api
	_content = run_content


## Lets go of the run if it is still `run_api` (a newer run's registration stays).
static func release(run_api: RunApi) -> void:
	if _api == run_api:
		_api = null
		_content = null


static func current_api() -> RunApi:
	return _api


static func current_content() -> ContentSet:
	return _content


## True when a generated run is registered (its seed and build can be shown).
static func has_variety_run() -> bool:
	return _api != null and _content != null and _content.is_variety()
