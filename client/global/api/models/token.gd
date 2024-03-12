extends BaseModel
class_name Token


var access_token: String
var token_type: String


func _parse_dict(dict: Dictionary) -> void:
	super._parse_dict(dict)
	if not has_data:
		return
	access_token = dict["access_token"]
	token_type = dict["token_type"]
