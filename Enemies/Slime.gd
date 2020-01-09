extends KinematicBody2D

enum State {IDLING, WALKING, SQUASHED}

export var gravity = 3800
export var max_speed = 30
var velocity = Vector2(0, 0)
var direction = 0
var state = State.IDLING

onready var AnimatedSprite = $AnimatedSprite
onready var Timer = $Timer
onready var Tween = $Tween
onready var GroundCheckLeft = $GroundCheckLeft
onready var GroundCheckRight = $GroundCheckRight
onready var WallCheckLeft = $WallCheckLeft
onready var WallCheckRight = $WallCheckRight

func _ready():
	call_deferred("set_state", State.IDLING)

func _physics_process(delta):
	# 计算x方向与y方向速度
	velocity.x = max_speed * direction
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity)

func set_state(new_state):
	state = new_state	# 设置当前状态
	# 根据不同的新状态作出处理
	match state:
		State.IDLING:
			direction = 0	# 静止
			AnimatedSprite.play("idle")
			Timer.start(0.5)	# 开启定时
		State.WALKING:
			direction = check_direction()	# 检测当前应该走的方向
			AnimatedSprite.play("walk")
			AnimatedSprite.flip_h = direction > 0
			Timer.start(0.5)
		State.SQUASHED:
			direction = 0
			AnimatedSprite.play("squashed")
			# 避免被再次踩踏
			set_collision_layer_bit(2, false)
			set_collision_mask_bit(1, false)
			# 禁用伤害区域
			$HitBox/CollisionShape2D.disabled = true
			# 淡出消失动画
			Tween.interpolate_property(AnimatedSprite, "modulate", AnimatedSprite.modulate, Color(1, 1, 1, 0), 1, Tween.TRANS_LINEAR, Tween.EASE_IN)
			Tween.start()

func check_direction():
	"""判断当前前进方向"""
	if not GroundCheckLeft.is_colliding():
		return 1
	elif not GroundCheckRight.is_colliding():
		return -1
	elif WallCheckLeft.is_colliding():
		return 1
	elif WallCheckRight.is_colliding():
		return -1
	elif direction == 0:
		return 1 if AnimatedSprite.flip_h else -1
	else:
		return direction

func trampled(trampler):
	"""被踩踏"""
	set_state(State.SQUASHED)
	if trampler.has_method("bounce"):
		trampler.bounce(-600)

func _on_Timer_timeout():
	# 定时器到点，在两个状态间切换
	if state == State.IDLING:
		set_state(State.WALKING)
	elif state == State.WALKING:
		set_state(State.IDLING)

func _on_Tween_tween_completed(object, key):
	if object == AnimatedSprite and key == ":modulate":
		queue_free()

func _on_HitBox_body_entered(body):
	if body.has_method("take_damage"):
		var bounce_force = body.position - self.position
		bounce_force = bounce_force.normalized() * 700
		body.take_damage(5, bounce_force)
