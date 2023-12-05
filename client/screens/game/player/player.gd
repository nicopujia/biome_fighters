extends CharacterBody2D


enum PhysicsLayers {NONE, PLAYER, BARRIER, BLOCK, HALF_PLATFORM}

const JUMP_IMPULSE: float = 166
const JUMPS_LIMIT: int = 2
const RUN_SPEED: float = 60
const CRAWL_SPEED: float = RUN_SPEED / 4
const SLIDE_SPEED: float = RUN_SPEED * 1.5
const GRAVITY_FORCE: float = 8

@export var starts_looking_left: bool

var _jumps_counter: int = 0
var _horizontal_direction: int = 0

@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _syncronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _coyote_jump_timer: Timer = $Timers/CoyoteJump
@onready var _jump_buffering_timer: Timer = $Timers/JumpBuffering
@onready var _fall_from_half_platform_timer: Timer = $Timers/FallFromHalfPlatform
@onready var _slide_timer: Timer = $Timers/Slide


func _ready() -> void:
	_sprite.flip_h = starts_looking_left


func _physics_process(delta: float) -> void:
	if not _syncronizer.is_multiplayer_authority():
		return
	
	# Input
	var down_is_pressed: bool = Input.is_action_pressed("ui_down")
	
	# Movement
	var was_on_floor: bool = is_on_floor()
	var previous_colliding_body_layer: PhysicsLayers = _get_colliding_body_layer()
	move_and_slide()
	
	# Horizontal movement
	if Input.is_action_pressed("ui_right"):
		_horizontal_direction = 1
	elif Input.is_action_pressed("ui_left"):
		_horizontal_direction = -1
	elif _slide_timer.is_stopped():
		_horizontal_direction = 0
	
	var speed: float = RUN_SPEED if _slide_timer.is_stopped() or not down_is_pressed else SLIDE_SPEED

	if down_is_pressed and is_on_floor() and _slide_timer.is_stopped():
		speed = CRAWL_SPEED
		
		if Input.is_action_just_pressed("punch"):
			speed = SLIDE_SPEED
			_horizontal_direction = -1 if _sprite.flip_h else 1
			_slide_timer.start()
	
	velocity.x = speed * _horizontal_direction
	
	# Vertical movement
	if Input.is_action_just_pressed("jump"):
		_jump_buffering_timer.start()
	
	var jump_has_been_pressed: bool = _jump_buffering_timer.time_left
	var is_not_falling_from_half_platform: bool = get_collision_mask_value(PhysicsLayers.HALF_PLATFORM)
	
	if velocity.y > 0 and _coyote_jump_timer.is_stopped() and _jumps_counter == 0:
		_jumps_counter = 1
		
	if is_on_floor() or _coyote_jump_timer.time_left:
		_jumps_counter = 0
		
		if jump_has_been_pressed:
			if down_is_pressed and _get_colliding_body_layer() == PhysicsLayers.HALF_PLATFORM:
				set_collision_mask_value(PhysicsLayers.HALF_PLATFORM, false)
				_fall_from_half_platform_timer.start()
				_jumps_counter += 1
			elif is_not_falling_from_half_platform:
				_jump()
	else:
		if was_on_floor and velocity.y > 0 and previous_colliding_body_layer != PhysicsLayers.HALF_PLATFORM:
			_coyote_jump_timer.start()
		
		if jump_has_been_pressed and is_not_falling_from_half_platform and _jumps_counter < JUMPS_LIMIT:
			_anim_player.play("spin")
			_jump()
	
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y /= 2
	
	velocity.y += GRAVITY_FORCE
	
	# Animation
	if velocity.x > 0:
		_sprite.flip_h = false
	elif velocity.x < 0:
		_sprite.flip_h = true
	
	if is_on_floor():
		if not was_on_floor:
			_anim_player.play_backwards("crouch")
		if velocity.x == 0:
			if down_is_pressed:
				if _anim_player.current_animation == "slide":
					_anim_player.play("crawl")
					_anim_player.advance(delta)
				if _anim_player.get_playing_speed() != -1 \
				   and _anim_player.current_animation_length == _anim_player.current_animation_position \
				   or _anim_player.current_animation == "crawl":
					_anim_player.pause()
				elif _anim_player.is_playing():
					_anim_player.play("crouch")
			elif Input.is_action_just_released("ui_down"):
				_anim_player.play_backwards("crouch")
			else:
				_play_or_queue_anim("idle", "crouch")
		else:
			if down_is_pressed:
				if abs(velocity.x) == CRAWL_SPEED:
					_anim_player.play("crawl")
				else:
					_anim_player.play("slide")
			else:
				_play_or_queue_anim("run", "crouch")
	else:
		_play_or_queue_anim("jump" if velocity.y < 0 else "fall", "spin")


func _jump() -> void:
	_jumps_counter += 1
	velocity.y = -JUMP_IMPULSE
	_jump_buffering_timer.stop()
	_coyote_jump_timer.stop()


func _get_colliding_body_layer() -> PhysicsLayers:
	var collision: Object = get_last_slide_collision()
	if collision == null:
		return PhysicsLayers.NONE
	var collider_rid: RID = collision.get_collider_rid()
	var layer_as_bitmask: int = PhysicsServer2D.body_get_collision_layer(collider_rid)
	return int(log(layer_as_bitmask) / log(2) + 1) as PhysicsLayers


## It queues or immediately plays "a" animation depending on if the current 
## animation is "b" or not, respectively
func _play_or_queue_anim(anim_a: StringName, anim_b: StringName) -> void:
	if _anim_player.current_animation == anim_b:
		_anim_player.queue(anim_a)
	else:
		_anim_player.play(anim_a)


func _on_fall_from_half_platform_timeout() -> void:
	set_collision_mask_value(PhysicsLayers.HALF_PLATFORM, true)
