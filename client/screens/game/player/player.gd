extends CharacterBody2D


const GRAVITY_FORCE: int = 10
const JUMP_IMPULSE: int = 200
const SPEED: int = 100

var sprite_frames_path: String
var starts_looking_left: bool

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _syncronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer


func _ready() -> void:
	_sprite.sprite_frames = load(sprite_frames_path)
	_sprite.flip_h = starts_looking_left
	_play_anim("idle")


func _physics_process(_delta: float) -> void:
	if not _syncronizer.is_multiplayer_authority():
		return
	
	
	if Input.is_action_pressed("ui_right"):
		velocity.x = SPEED
	elif Input.is_action_pressed("ui_left"):
		velocity.x = -SPEED
	else:
		velocity.x = 0
	
	if Input.is_action_just_pressed("jump"):
		velocity.y = -JUMP_IMPULSE
	
	if Input.is_action_just_pressed("ui_right"):
		_sprite.flip_h = false
	
	if Input.is_action_just_pressed("ui_left"):
		_sprite.flip_h = true
	
	if is_on_floor() and not is_on_wall() and velocity.x:
		_play_anim("run")
	
	if is_on_floor() and not velocity.x:
		_play_anim("idle")
	
	if not is_on_floor():
		_play_anim("jump")
	
	
	velocity.y += GRAVITY_FORCE
	
	move_and_slide()


func _play_anim(anim_name: StringName) -> void:
	if _sprite.animation != anim_name:
		_sprite.play(anim_name)
