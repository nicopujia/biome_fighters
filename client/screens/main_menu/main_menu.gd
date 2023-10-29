extends Panel


@onready var _loading_screen: Control = $LoadingScreen
@onready var _loading_screen_label: Label = $LoadingScreen/Label
@onready var _loading_screen_button: Button = $LoadingScreen/Button
@onready var _content: Control = $Content
@onready var _username_label: Label = $Content/UsernameLabel


func _ready() -> void:
	_set_loading_state(true)
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
		_loading_screen_button.text = button_text
		for connection in _loading_screen_button.pressed.get_connections():
			_loading_screen_button.pressed.disconnect(connection["callable"])
		_loading_screen_button.pressed.connect(button_action)
	
	_loading_screen_label.text = message
	_content.visible = not is_loading
	_loading_screen.visible = is_loading


func _load_user_data() -> void:
	var response = await Network.call_server_with_auth_token("users/me")
	var body: Dictionary = response["body"]
	match response["status_code"]:
		HTTPClient.RESPONSE_OK:
			_show_user_data(body)
			_set_loading_state(false)
			
		HTTPClient.RESPONSE_UNAUTHORIZED:
			get_tree().change_scene_to_file("res://screens/auth/auth_screen.tscn")
		
		Error.ERR_CANT_CONNECT:
			_set_loading_state(true, body["detail"], "Try again", _ready)


func _show_user_data(data: Dictionary):
	_username_label.text = data["username"]
	# More data will be added in the future


func _on_logout_button_pressed() -> void:
	UserData.save_value("Auth", "access_token", "")
	get_tree().change_scene_to_file("res://screens/auth/auth_screen.tscn")
