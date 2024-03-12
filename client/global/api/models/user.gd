extends BaseModel
class_name User


var username: String


func _parse_dict(dict: Dictionary) -> void:
	super._parse_dict(dict)
	if not has_data:
		return
	username = dict["username"]
