class_name Player
extends CharacterBody2D


signal health_changed(new_value: float)

enum PhysicsLayers {NONE, PLAYER, BARRIER, BLOCK, HALF_PLATFORM, HITBOX}

const GRAVITY_FORCE: float = 8
const JUMP_IMPULSE: float = 166
const JUMPS_LIMIT: int = 2
const RUN_SPEED: float = 60
const CRAWL_SPEED: float = RUN_SPEED / 4
const SLIDE_SPEED: float = RUN_SPEED * 1.5
const PUNCH_DAMAGE: float = 1
const SLIDE_DAMAGE: float = PUNCH_DAMAGE * 2
const PUNCH_FRAMES: PackedInt32Array = [12, 14]
const INITIAL_HEALTH: float = 20

@export_enum("Left:-1", "Right:1") var initial_looking_direction: int = 1
@export var anim_player: AnimationPlayer
@export var sprite: Sprite2D
@export var synchronizer: MultiplayerSynchronizer
@export_group("Colliders")
@export var hitbox_collider: CollisionShape2D
@export var crouched_collider: CollisionShape2D
@export var stood_up_collider: CollisionShape2D
@export_group("Timers")
@export var coyote_jump_timer: Timer
@export var fall_from_half_platform_timer: Timer
@export var jump_buffering_timer: Timer
@export var slide_timer: Timer

var health: float = INITIAL_HEALTH

var _horizontal_direction: int
var _jumps_counter: int


func _ready() -> void:
	sprite.scale.x = initial_looking_direction


func _physics_process(delta: float) -> void:
	# Multiplayer
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	
	if not synchronizer.is_multiplayer_authority():
		return
	
	# Common input
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
	elif slide_timer.is_stopped():
		_horizontal_direction = 0
	
	var speed: float = RUN_SPEED if slide_timer.is_stopped() or not down_is_pressed else SLIDE_SPEED
	
	if down_is_pressed and is_on_floor() and slide_timer.is_stopped():
		speed = CRAWL_SPEED
		
		if Input.is_action_just_pressed("punch"):
			speed = SLIDE_SPEED
			_horizontal_direction = int(sprite.scale.x)
			slide_timer.start()
			hitbox_collider.set_deferred("disabled", false)
	
	velocity.x = speed * _horizontal_direction
	
	# Vertical movement
	if Input.is_action_just_pressed("jump"):
		jump_buffering_timer.start()
		
	var jump_has_been_pressed: bool = jump_buffering_timer.time_left
	var is_not_falling_from_half_platform: bool = get_collision_mask_value(PhysicsLayers.HALF_PLATFORM)
	
	if velocity.y > 0 and coyote_jump_timer.is_stopped() and _jumps_counter == 0:
		_jumps_counter = 1
		
	if is_on_floor() or coyote_jump_timer.time_left:
		_jumps_counter = 0
		
		if jump_has_been_pressed:
			if down_is_pressed and _get_colliding_body_layer() == PhysicsLayers.HALF_PLATFORM:
				set_collision_mask_value(PhysicsLayers.HALF_PLATFORM, false)
				fall_from_half_platform_timer.start()
				_jumps_counter += 1
			elif is_not_falling_from_half_platform:
				jump(JUMP_IMPULSE)
	else:
		if was_on_floor and velocity.y > 0 and previous_colliding_body_layer != PhysicsLayers.HALF_PLATFORM:
			coyote_jump_timer.start()
		
		if jump_has_been_pressed and is_not_falling_from_half_platform and _jumps_counter < JUMPS_LIMIT:
			jump(JUMP_IMPULSE)
			
			if not anim_player.current_animation.begins_with("punch"):
				anim_player.play("spin")
	
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y /= 2
	
	velocity.y += GRAVITY_FORCE
	
	# Collider when crouched
	if Input.is_action_just_pressed("ui_down"):
		crouched_collider.set_deferred("disabled", false)
		stood_up_collider.set_deferred("disabled", true)
	
	if Input.is_action_just_released("ui_down"):
		crouched_collider.set_deferred("disabled", true)
		stood_up_collider.set_deferred("disabled", false)
	
	# Animation
	if velocity.x > 0:
		sprite.scale.x = 1
	elif velocity.x < 0:
		sprite.scale.x = -1
	
	if Input.is_action_just_pressed("punch") and not down_is_pressed:
		if anim_player.current_animation == "punch_1":
			anim_player.clear_queue()
			anim_player.queue("punch_2")
		elif anim_player.current_animation != "punch_2":
			anim_player.play("punch_1")
		anim_player.queue("idle")
	
	if slide_timer.is_stopped():
		hitbox_collider.set_deferred("disabled", not sprite.frame in PUNCH_FRAMES)
	
	if anim_player.current_animation.begins_with("punch") \
	   and anim_player.current_animation_position != anim_player.current_animation_length:
		return
	
	if is_on_floor():
		if not was_on_floor and not anim_player.current_animation == "hurt":
			anim_player.play_backwards("crouch")
		if velocity.x == 0:
			if down_is_pressed:
				if anim_player.current_animation == "slide":
					anim_player.play("crawl")
					anim_player.advance(delta)
				if anim_player.get_playing_speed() != -1 \
				   and anim_player.current_animation_length == anim_player.current_animation_position \
				   or anim_player.current_animation == "crawl":
					anim_player.pause()
				elif anim_player.is_playing():
					anim_player.play("crouch")
			elif Input.is_action_just_released("ui_down"):
				anim_player.play_backwards("crouch")
			else:
				_play_or_queue_anim("idle", ["crouch", "hurt"])
		else:
			if down_is_pressed:
				if abs(velocity.x) == CRAWL_SPEED:
					anim_player.play("crawl")
				else:
					anim_player.play("slide")
			else:
				_play_or_queue_anim("run", ["crouch"])
	else:
		_play_or_queue_anim("jump" if velocity.y < 0 else "fall", ["spin", "hurt"])


func jump(impulse: float) -> void:
	velocity.y = -impulse
	_jumps_counter += 1
	jump_buffering_timer.stop()
	coyote_jump_timer.stop()


func take_damage(amount: int) -> void:
	anim_player.stop()
	anim_player.play("hurt")
	health -= amount
	health_changed.emit(health)


func _get_colliding_body_layer() -> PhysicsLayers:
	var collision: Object = get_last_slide_collision()
	if collision == null:
		return PhysicsLayers.NONE
	var collider_rid: RID = collision.get_collider_rid()
	var layer_as_bitmask: int = PhysicsServer2D.body_get_collision_layer(collider_rid)
	return int(log(layer_as_bitmask) / log(2) + 1) as PhysicsLayers


## If the current animation is any of the [param wait_animations], the 
## [param main_animation] is queued. Otherwise, it is played immediately.
func _play_or_queue_anim(main_animation: StringName, wait_animations: PackedStringArray) -> void:
	if anim_player.current_animation in wait_animations:
		anim_player.queue(main_animation)
	else:
		anim_player.play(main_animation)


func _on_fall_from_half_platform_timeout() -> void:
	set_collision_mask_value(PhysicsLayers.HALF_PLATFORM, true)


func _on_hit_box_body_entered(body: Node2D) -> void:
	if body == self:
		return
	
	var damage: float = PUNCH_DAMAGE
	
	if not crouched_collider.disabled and body.has_method("jump"):
		damage = SLIDE_DAMAGE
		body.jump(JUMP_IMPULSE / 2)
	
	body.take_damage(damage)



func _on_slide_timeout() -> void:
	hitbox_collider.set_deferred("disabled", true)
