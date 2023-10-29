extends Panel


@onready var _loading_screen = $LoadingScreen
@onready var _content = $Content
@onready var _username_label = $Content/UsernameLabel


func _ready() -> void:
	_set_loading_state(true)
	var response = await Globals.call_server("users/me")
	match response["status_code"]:
		HTTPClient.RESPONSE_OK:
			var user_info: Dictionary = response["body"]
			_username_label.text = user_info["username"]
			_set_loading_state(false)
			
		HTTPClient.RESPONSE_UNAUTHORIZED:
			get_tree().change_scene_to_packed(Globals.AUTH_SCREEN)


func _set_loading_state(is_loading: bool) -> void:
	_content.visible = not is_loading
	_loading_screen.visible = is_loading


func _on_logout_button_pressed() -> void:
	Globals.access_token = ""
	get_tree().change_scene_to_packed(Globals.AUTH_SCREEN)
