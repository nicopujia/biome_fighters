extends Panel


@export var username_label: Label


func _ready() -> void:
	await _load_user_data()


func _load_user_data() -> void:
	LoadingScreen.communicate()
	
	var response: Server.HTTPResponse = await Server.request("/me")
	
	if response.result == HTTPRequest.RESULT_TIMEOUT:
		LoadingScreen.communicate(
			"Request took too long. Please, check your internet connection and try again", 
			"Try again", 
			_load_user_data
		)
			
	elif response.status_code == HTTPClient.RESPONSE_OK:
		Server.me = Server.User.new(response.body)
		_show_user_data()
		LoadingScreen.hide()
		
	elif response.status_code == HTTPClient.RESPONSE_UNAUTHORIZED:
		get_tree().change_scene_to_file("res://screens/auth/auth_screen.tscn")
		LoadingScreen.hide()
		
	else:
		LoadingScreen.communicate("Unexpected error occurred with result %s, status code %s" % [response.result, response.status_code])


func _show_user_data():
	username_label.text = Server.me.username
	# More data will be added in the future


func _on_logout_button_pressed() -> void:
	PersistentData.save_value("Auth", "access_token", "")
	get_tree().change_scene_to_file("res://screens/auth/auth_screen.tscn")


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screens/game/game_screen.tscn")
