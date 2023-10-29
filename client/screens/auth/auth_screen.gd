extends Panel


@onready var _http = $HTTPRequest
@onready var _username_input = $Content/UsernameInput
@onready var _password_input = $Content/PasswordInput
@onready var _repeated_password_input = $Content/RepeatPasswordInput
@onready var _info_label = $Content/InfoLabel
@onready var _buttons = $Content/Buttons


func _on_auth_button_pressed(is_login: bool) -> void:
	if not _username_input.text \
	   or not _password_input.text \
	   or not _repeated_password_input.text:
		_info_label.text = "Please complete all the fields"
		return
	
	if  _password_input.text != _repeated_password_input.text:
		_info_label.text = "Passwords do not match"
		return
	
	_set_buttons_avaiability(false)
	
	var url = "http://%s:%s/users/%s" % [
		Globals.SERVER_DOMAIN, 
		Globals.SERVER_PORT,
		"login" if is_login else "register",
	]
	var method: int = HTTPClient.METHOD_POST
	var body: String = "username=%s&password=%s" % [
		_username_input.text, _password_input.text
	]
	var headers: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded",
		"Content-Lenght: " + str(body.to_utf8_buffer().size()),
	]
	
	var error: Error = _http.request(url, headers, method, body)
	
	if error != OK:
		_info_label.text = "Request failed"
		_set_buttons_avaiability(true)


func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_json: Dictionary = JSON.parse_string(body.get_string_from_utf8())
	
	match response_code:
		HTTPClient.RESPONSE_OK:
			Globals.access_token = response_json["access_token"]
			get_tree().change_scene_to_packed(Globals.MAIN_MENU_SCREEN)
		
		HTTPClient.RESPONSE_BAD_REQUEST:
			_info_label.text = response_json["detail"]
			_set_buttons_avaiability(true)


func _set_buttons_avaiability(enabled: bool) -> void:
	for button in _buttons.get_children():
		button.disabled = not enabled
