extends Panel


@onready var _username_input: LineEdit = $Content/UsernameInput
@onready var _password_input: LineEdit = $Content/PasswordInput
@onready var _repeated_password_input: LineEdit = $Content/RepeatPasswordInput
@onready var _info_label: Label = $Content/InfoLabel
@onready var _buttons: HBoxContainer = $Content/Buttons
@onready var _http: HTTPRequest = $HTTPRequest


func _on_auth_button_pressed(endpoint: StringName) -> void:
	if not _fields_are_valid():
		return
	
	var url: String = Server.build_url("http", endpoint)
	var body: String = HTTPClient.new().query_string_from_dict({
		"username": _username_input.text, 
		"password": _password_input.text,
	})
	var headers: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded",
		"Content-Lenght: " + str(body.to_utf8_buffer().size()),
	]
	_http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	var response: Server.HTTPResponse = Server.HTTPResponse.new(await _http.request_completed)

	if response.status_code != HTTPClient.RESPONSE_CREATED:
		_info_label.text = response.body["detail"]
		_set_buttons_avaiability(true)
		return
		
	if endpoint == "/login":
		UserData.save_value("Auth", "access_token", response.body["access_token"])
		get_tree().change_scene_to_file("res://screens/main_menu/main_menu_screen.tscn")
	else:
		_info_label.text = "User registered. Logging in..."
		_on_auth_button_pressed("/login")


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
