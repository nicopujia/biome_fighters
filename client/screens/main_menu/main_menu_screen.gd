extends Panel


@onready var _username_label: Label = $Content/UsernameLabel


func _ready() -> void:
	_load_user_data()


func _load_user_data() -> void:
	LoadingScreen.set_state(true)
	var response: Server.HTTPResponse = await Server.request("/me")
	
	if response.result == HTTPRequest.RESULT_TIMEOUT:
		LoadingScreen.set_state(true, "Request took too long. Please, check your internet connection and try again", "Try again", _load_user_data)
		
	elif response.status_code == HTTPClient.RESPONSE_OK:
		_show_user_data(response.body)
		LoadingScreen.set_state(false)
		
	elif response.status_code == HTTPClient.RESPONSE_UNAUTHORIZED:
		get_tree().change_scene_to_file("res://screens/auth/auth_screen.tscn")
		LoadingScreen.set_state(false)
		
	else:
		LoadingScreen.set_state(true, "Unexpected error occurred with result %s, status code %s" % [response.result, response.status_code])


func _show_user_data(data: Dictionary):
	_username_label.text = data["username"]
	# More data will be added in the future


func _on_logout_button_pressed() -> void:
	PersistentData.save_value("Auth", "access_token", "")
	get_tree().change_scene_to_file("res://screens/auth/auth_screen.tscn")


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screens/game/game_screen.tscn")
