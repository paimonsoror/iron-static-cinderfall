extends GdUnitTestSuite
## MobileShell: app-pause flushes the profile and reports; the back request is reported; Escape stands in on desktop.

var _fs: MemorySaveFs
var _shell: MobileShell
var _paused: int = 0
var _backs: int = 0


func before_test() -> void:
	_fs = GameRunKit.fresh_save()
	_paused = 0
	_backs = 0
	_shell = MobileShell.new()
	auto_free(_shell)
	add_child(_shell)
	_shell.app_paused.connect(_on_paused)
	_shell.back_requested.connect(_on_back)


func after_test() -> void:
	GameRunKit.reset_save()


func _on_paused() -> void:
	_paused += 1


func _on_back() -> void:
	_backs += 1


func _saved_data() -> int:
	return ProfileCodec.decode(_fs.read(Save.PATH_MAIN)).profile.data


func test_app_pause_writes_the_profile_and_then_reports() -> void:
	Save.profile.data = 77  # a change nothing has flushed yet
	assert_bool(_fs.exists(Save.PATH_MAIN)).is_false()
	_shell.on_app_paused()
	assert_int(_saved_data()).is_equal(77)
	assert_int(_paused).is_equal(1)


func test_a_failed_flush_on_app_pause_is_remembered_for_a_retry() -> void:
	Save.profile.data = 5
	_fs.fail_writes = true
	_shell.on_app_paused()
	assert_int(_paused).is_equal(1)  # the pause still happens
	assert_bool(GameRewards.flush_pending).is_true()
	_fs.fail_writes = false
	assert_bool(GameRewards.retry_pending()).is_true()
	assert_int(_saved_data()).is_equal(5)


func test_the_os_back_request_is_reported() -> void:
	_shell.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_int(_backs).is_equal(1)
	assert_int(_paused).is_equal(0)


func test_the_lifecycle_notifications_only_pause_on_a_mobile_build() -> void:
	_shell.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_shell.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(_paused).is_equal(1 if OS.has_feature("mobile") else 0)


func test_escape_acts_as_the_back_gesture() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = &"ui_cancel"
	press.pressed = true
	_shell._unhandled_input(press)
	assert_int(_backs).is_equal(1)


func test_other_input_and_a_release_do_not() -> void:
	var release: InputEventAction = InputEventAction.new()
	release.action = &"ui_cancel"
	release.pressed = false
	_shell._unhandled_input(release)
	var other: InputEventAction = InputEventAction.new()
	other.action = &"ui_accept"
	other.pressed = true
	_shell._unhandled_input(other)
	assert_int(_backs).is_equal(0)
