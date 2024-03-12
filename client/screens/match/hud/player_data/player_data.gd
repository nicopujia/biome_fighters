@tool
class_name PlayerData
extends HBoxContainer

# "onready" variables aren't used because they cause errors in the setters

@export var flip_h: bool = false:
	set(new_value):
		flip_h = new_value
		$VBoxContainer/UsernameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if flip_h else 0
		$VBoxContainer/HealthBar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if flip_h else ProgressBar.FILL_BEGIN_TO_END
		$CharacterThumbnailNode.flip_h = flip_h
		move_child($CharacterThumbnailNode, -1 if flip_h else 0)
@export var username: String = "Player's username":
	set(new_value):
		username = new_value
		$VBoxContainer/UsernameLabel.text = username
		update_configuration_warnings()
@export var character_thumbnail: Texture2D:
	set(new_value):
		character_thumbnail = new_value
		$CharacterThumbnailNode.texture = character_thumbnail
@export_group("Health Bar")
@export var max_health: float = 100:
	set(new_value):
		max_health = new_value
		$VBoxContainer/HealthBar.max_value = max_health
		update_configuration_warnings()
@export var health: float = 50:
	set(new_value):
		health = new_value
		$VBoxContainer/HealthBar.value = health
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if username.length() > 20:
		warnings.append("`username` must be less or equal than 20 characters long.")
	
	if health > max_health:
		warnings.append("`health` must be less or equal than `max_health`")
	
	return warnings
