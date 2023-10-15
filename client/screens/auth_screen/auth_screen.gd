extends Panel


@onready var _username_input := $Content/UsernameInput
@onready var _password_input := $Content/PasswordInput
@onready var _repeated_password_input := $Content/RepeatPasswordInput
@onready var _info_label := $Content/InfoLabel


func _ready() -> void:
	# TODO: if user is logged in: go directly to main_menu.tscn
	pass


func _on_login_button_pressed() -> void:
	if not _fields_are_valid():
		return
	
	match Server.login(_username_input.text, _password_input.text):
		OK:
			get_tree().change_scene_to_file("res://screens/main_menu/main_menu.tscn")


func _on_register_button_pressed() -> void:
	if not _fields_are_valid():
		return
		
	match Server.register_user(_username_input.text, _password_input.text):
		OK:
			get_tree().change_scene_to_file("res://screens/main_menu/main_menu.tscn")


func _fields_are_valid() -> bool:
	if not _username_input.text or not _password_input.text or not _repeated_password_input.text:
		_info_label.text = "Please complete all the fields"
		return false
		
	if  _password_input.text != _repeated_password_input.text:
		_info_label.text = "Passwords do not match"
		return false
	
	return true
