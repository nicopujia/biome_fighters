extends Object
class_name BaseModel

## Base class for creating parsers for response bodies, a.k.a. models
##
## Inherited classes should have their fields as members and override 
## [method _parse_dict], as follows:
## [codeblock]
## extends BaseModel
## class_name ExampleModel
##
## var example_field: String
## # More fields here
##
## func _parse_dict(dict: Dictionary) -> void:
##     super._parse_dict(dict)
##     if not has_data:
##         return
##     example_field = dict["example_field"]
##     # More fields here
## [/codeblock]


## Indicates whether or not the model has data. Usually, it's false when
## there was an error in the response (which can probably be handled by calling
## [method APIResponse.hadle_common_errors]).
var has_data: bool


func _init(data: Variant) -> void:
	if data is APIResponse:
		_parse_response(data)
	elif data is Dictionary:
		_parse_dict(data)
	else:
		assert(false, "Parameter 'data' must be of type 'Dictionary' or 'APIResponse'")


func _parse_response(response: APIResponse) -> void:
	has_data = response.succeeded()
	if has_data:
		_parse_dict(response.body)


func _parse_dict(dict: Dictionary) -> void:
	has_data = not dict.is_empty()
