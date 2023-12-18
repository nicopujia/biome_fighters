extends Panel


@export var username_input: LineEdit
@export var password_input: LineEdit
@export var repeated_password_input: LineEdit
@export var info_label: Label
@export var buttons: HBoxContainer
@export var http: HTTPRequest


func _on_auth_button_pressed(endpoint: StringName) -> void:
	if not _fields_are_valid():
		return
	
	var url: String = Server.build_url("http", endpoint)
	var body: String = HTTPClient.new().query_string_from_dict({
		"username": username_input.text, 
		"password": password_input.text,
	})
	var headers: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded",
		"Content-Lenght: " + str(body.to_utf8_buffer().size()),
	]
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	var response: Server.HTTPResponse = Server.HTTPResponse.new(await http.request_completed)

	if response.status_code != HTTPClient.RESPONSE_CREATED:
		info_label.text = response.body["detail"]
		_set_buttons_avaiability(true)
		return
		
	if endpoint == "/login":
		PersistentData.save_value("Auth", "access_token", response.body["access_token"])
		get_tree().change_scene_to_file("res://screens/main_menu/main_menu_screen.tscn")
	else:
		info_label.text = "User registered. Logging in..."
		_on_auth_button_pressed("/login")


func _fields_are_valid() -> bool:
	if not username_input.text \
	   or not password_input.text \
	   or not repeated_password_input.text:
		info_label.text = "Please complete all the fields"
		return false
	
	if  password_input.text != repeated_password_input.text:
		info_label.text = "Passwords do not match"
		return false
	
	return true


func _set_buttons_avaiability(enabled: bool) -> void:
	for button in buttons.get_children():
		button.disabled = not enabled
