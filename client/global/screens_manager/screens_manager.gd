extends CanvasLayer


@export var auth_screen: PackedScene
@export var main_menu_screen: PackedScene
@export var match_screen: PackedScene
@export var intermediate_screen_label: Label
@export var intermediate_screen_button: Button


func go_to_auth_screen():
	_go_to(auth_screen)


func go_to_main_menu_screen():
	_go_to(main_menu_screen)


func go_to_match_screen():
	_go_to(match_screen)


func show_intermediate_screen(
	message: String = "Loading...", 
	button_text: String = "", 
	button_action: Callable = hide
) -> void:
	if button_text.is_empty():
		intermediate_screen_button.hide()
	else:
		_clear_button_connections()
		intermediate_screen_button.pressed.connect(button_action)
		intermediate_screen_button.text = button_text
		intermediate_screen_button.show()
	intermediate_screen_label.text = message
	show()


func _go_to(screen: PackedScene) -> void:
	get_tree().change_scene_to_packed(screen)
	hide()


func _clear_button_connections() -> void:
	for connection in intermediate_screen_button.pressed.get_connections():
		intermediate_screen_button.pressed.disconnect(connection["callable"])
