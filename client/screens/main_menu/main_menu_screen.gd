extends Panel


@onready var _loading_screen: Control = $LoadingScreen
@onready var _loading_screen_label: Label = $LoadingScreen/Label
@onready var _loading_screen_button: Button = $LoadingScreen/Button
@onready var _content: Control = $Content
@onready var _username_label: Label = $Content/UsernameLabel


func _ready() -> void:
	_load_user_data()


func _set_loading_state(
	is_loading: bool,
	message: String = "Loading...",
	button_text: String = "",
	button_action: Callable = Callable()
) -> void:
	if button_text.is_empty():
		_loading_screen_button.hide()
	else:
		_loading_screen_button.show()
		_loading_screen_button.text = button_text
		for connection in _loading_screen_button.pressed.get_connections():
			_loading_screen_button.pressed.disconnect(connection["callable"])
		_loading_screen_button.pressed.connect(button_action)
	
	_loading_screen_label.text = message
	_content.visible = not is_loading
	_loading_screen.visible = is_loading


func _load_user_data() -> void:
	_set_loading_state(true, "Loading user data...")
	var response = await Network.call_server_with_auth_token("users/me")
	var status_code: int = response["status_code"]
	
	if status_code == HTTPClient.RESPONSE_OK:
		_show_user_data(response["body"])
		_set_loading_state(false)
		
	elif status_code == HTTPClient.RESPONSE_UNAUTHORIZED:
		get_tree().change_scene_to_file("res://screens/auth/auth_screen.tscn")
		
	elif status_code == HTTPRequest.RESULT_TIMEOUT \
		 or status_code == HTTPRequest.RESULT_CANT_CONNECT \
		 or status_code == HTTPRequest.RESULT_CANT_RESOLVE:
			_set_loading_state(true, "Request took too long. Please, check your internet connection and try again", "Try again", _load_user_data)
		
	else:
		_set_loading_state(true, "An unexpected error occurred with status code " + str(status_code))


func _show_user_data(data: Dictionary):
	_username_label.text = data["username"]
	# More data will be added in the future


func _on_logout_button_pressed() -> void:
	UserData.save_value("Auth", "access_token", "")
	get_tree().change_scene_to_file("res://screens/auth/auth_screen.tscn")
