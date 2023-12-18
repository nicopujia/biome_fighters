extends CanvasLayer


@export var label: Label
@export var button: Button


func communicate(message: String = "Loading...", button_text: String = "", button_action: Callable = Callable()) -> void:
	if button_text.is_empty():
		button.hide()
	else:
		button.show()
		button.text = button_text
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection["callable"])
		button.pressed.connect(button_action)
	
	label.text = message
	show()
