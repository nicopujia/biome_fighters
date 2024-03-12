extends Panel


@export var username_label: Label


func _ready() -> void:
	_fetch_current_user_data()


func _fetch_current_user_data() -> void:
	ScreensManager.show_intermediate_screen()
	var current_user := await API.request_current_user()
	if current_user.has_data:
		_update_current_user_data(current_user)
		ScreensManager.hide()


func _update_current_user_data(current_user: User) -> void:
	username_label.text = current_user.username
	# More data will be added in the future


func _on_logout_button_pressed() -> void:
	API.logout()
	ScreensManager.go_to_auth_screen()


func _on_play_button_pressed() -> void:
	ScreensManager.go_to_match_screen()
