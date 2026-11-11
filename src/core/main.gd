extends Node
## Entry point (ARCH 7.4, frozen). A capture request renders one scene and quits; otherwise the game boots.


func _ready() -> void:
	var args: DebugArgs = DebugArgs.from_os()
	if args.wants_capture():
		var runner: CaptureRunner = CaptureRunner.new()
		runner.setup(args)
		add_child(runner)
		return
	Game.boot(self)
