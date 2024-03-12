extends Panel


@export var username_input: LineEdit
@export var password_input: LineEdit
@export var repeated_password_input: LineEdit
@export var info_label: Label


func _on_auth_button_pressed(method: StringName) -> void:
	if not _validate_inputs():
		return
		
	_set_buttons_disabled(true)
	
	var error_message: String = await API.call(method, username_input.text, password_input.text)
	
	if error_message:
		_show_message(error_message)
		_set_buttons_disabled(false)
	else:
		ScreensManager.go_to_main_menu_screen()


func _validate_inputs() -> bool:
	if username_input.text.is_empty() \
	   or password_input.text.is_empty() \
	   or repeated_password_input.text.is_empty():
		_show_message("Please complete all the fields")
		return false
	
	if password_input.text != repeated_password_input.text:
		_show_message("Passwords don't match")
		return false
	
	return true


func _set_buttons_disabled(disabled: bool) -> void:
	get_tree().set_group("buttons", "disabled", disabled)


func _show_message(message: String) -> void:
	info_label.text = message
