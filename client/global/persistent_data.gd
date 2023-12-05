extends Node


const _CONFIG_FILE_PATH: String = "user://data.cfg"

var _config_file: ConfigFile = ConfigFile.new()


func _ready() -> void:
	_config_file.load(_CONFIG_FILE_PATH)


func save_value(section: String, key: String, value: Variant) -> void:
	_config_file.set_value(section, key, value)
	_config_file.save(_CONFIG_FILE_PATH)


func get_value(section: String, key: String, default: Variant = null) -> String:
	return _config_file.get_value(section, key, default)
