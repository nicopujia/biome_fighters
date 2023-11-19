extends CanvasLayer


@onready var _label: Label = $Panel/Label
@onready var _button: Button = $Panel/Button


func set_state(is_loading: bool, message: String = "Loading...", button_text: String = "", button_action: Callable = Callable()) -> void:
	if button_text.is_empty():
		_button.hide()
	else:
		_button.show()
		_button.text = button_text
		for connection in _button.pressed.get_connections():
			_button.pressed.disconnect(connection["callable"])
		_button.pressed.connect(button_action)
	
	_label.text = message
	visible = is_loading
