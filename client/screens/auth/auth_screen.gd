extends Panel


@onready var _username_input = $Content/UsernameInput
@onready var _password_input = $Content/PasswordInput
@onready var _repeated_password_input = $Content/RepeatPasswordInput
@onready var _info_label = $Content/InfoLabel
@onready var _buttons = $Content/Buttons


func _on_auth_button_pressed(is_logging_in: bool) -> void:
	if not _fields_are_valid():
		return
	
	_set_buttons_avaiability(false)
	
	var endpoint: String = "login" if is_logging_in else "register"
	var url: String = "https://%s/users/%s" % [Network.SERVER_DOMAIN, endpoint]
	var method: int = HTTPClient.METHOD_POST
	var body: String = "username=%s&password=%s" % [
		_username_input.text, _password_input.text
	]
	var headers: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded",
		"Content-Lenght: " + str(body.to_utf8_buffer().size()),
	]
	
	var response: Dictionary = await Network.make_http_request(url, headers, method, body)
	var response_body: Dictionary = response["body"]
	
	if response["status_code"] == HTTPClient.RESPONSE_OK:
		var access_token: String = response_body["access_token"]
		UserData.save_value("Auth", "access_token", access_token)
		get_tree().change_scene_to_file("res://screens/main_menu/main_menu_screen.tscn")
	else:
		_info_label.text = response_body["detail"]
		_set_buttons_avaiability(true)


func _fields_are_valid() -> bool:
	if not _username_input.text \
	   or not _password_input.text \
	   or not _repeated_password_input.text:
		_info_label.text = "Please complete all the fields"
		return false
	
	if  _password_input.text != _repeated_password_input.text:
		_info_label.text = "Passwords do not match"
		return false
	
	return true


func _set_buttons_avaiability(enabled: bool) -> void:
	for button in _buttons.get_children():
		button.disabled = not enabled
