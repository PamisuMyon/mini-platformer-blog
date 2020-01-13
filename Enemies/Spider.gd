extends KinematicBody2D
class_name Spider

const FLOOR_NORMAL = Vector2.UP
# 状态：静止、行走、突袭、死亡
enum {IDLE, WALK, ASSAULT, DEAD}

# 活动距离[最小，最大]
export (Array) var active_range := [50, 80]

var gravity = 3800
var max_speed_normal = 250	# 正常速度
var max_speed_assault = 400	# 突袭速度
var max_speed = max_speed_normal
var velocity = Vector2(0, 0)
var direction = 0
var target: Vector2	# 当前目标位置
var player: Player	# 处于检测范围内的玩家
var state = IDLE	# 当前状态

# 子节点
onready var AnimatedSprite = $AnimatedSprite
onready var GroundCheckLeft = $GroundCheckLeft
onready var GroundCheckRight = $GroundCheckRight
onready var WallCheckLeft = $WallCheckLeft
onready var WallCheckRight = $WallCheckRight
onready var Tween = $Tween

func _ready():
	set_state(IDLE)

func _physics_process(delta):
	match state:
		WALK:
			# 到达目的地则停止
			if position.distance_squared_to(target) < 16:
				set_state(IDLE)
				continue	#跳出match
			# 判断行进方向
			var new_direction = _check_direction()
			if direction != 0 and direction != new_direction:
				# 平台边缘则停止
				set_state(IDLE)
			else:
				direction = new_direction
		ASSAULT:
			# 到达目的地处理
			if position.distance_squared_to(target) < 16:
				# 玩家存在感知区域则继续突袭
				if player != null:
					target = player.position
				else:
					set_state(WALK)
					continue
			# 判断行进方向
			var new_direction = _check_direction()
			if direction != 0 and direction != new_direction:
				# 平台边缘处理
				if player != null:
					target = player.position
				else:
					set_state(WALK)
			else:
				direction = new_direction
	
	# 动画水平翻转
	if direction > 0:
		AnimatedSprite.flip_h = true
	elif direction < 0:
		AnimatedSprite.flip_h = false
	# 计算x方向与y方向速度
	velocity.x = lerp(velocity.x, max_speed * direction, 0.3)
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, FLOOR_NORMAL)

func set_state(new_state):
	"""设置状态"""
	if state == DEAD: return
	state = new_state
	match state:
		IDLE:
			# 静止状态，停留一段时间，若感知到玩家则攻击，无则行走
			AnimatedSprite.play("idle")
			direction = 0
			var state_stay = rand_range(0.6, 1.2)
			yield(get_tree().create_timer(state_stay), "timeout")
			if player != null:
				set_state(ASSAULT)
			else:
				set_state(WALK)
		WALK:
			# 行走状态，随机取点前进
			AnimatedSprite.play("walk")
			max_speed = max_speed_normal
			var tar_x = rand_range(active_range[0], active_range[1])
			tar_x *= 1 if randf() > 0.5 else -1
			tar_x += position.x
			target = Vector2(tar_x, position.y)
		ASSAULT:
			# 突袭状态，目标已由感知区域确定
			AnimatedSprite.play("walk")
			max_speed = max_speed_assault
		DEAD:
			# 死亡状态
			direction = 0
			AnimatedSprite.play("dead")
			# 避免被再次踩踏
			set_collision_layer_bit(2, false)
			set_collision_mask_bit(1, false)
			# 禁用伤害区域与检测区域
			$HitBox/CollisionShape2D.disabled = true
			$DetectingBox/CollisionShape2D.disabled = true
			# 淡出消失动画
			Tween.interpolate_property(AnimatedSprite, "modulate", AnimatedSprite.modulate, Color(1, 1, 1, 0), 1, Tween.TRANS_LINEAR, Tween.EASE_IN)
			Tween.start()

func _check_direction():
	"""判断当前前进方向"""
	if not GroundCheckLeft.is_colliding():
		return 1
	elif not GroundCheckRight.is_colliding():
		return -1
	elif WallCheckLeft.is_colliding():
		return 1
	elif WallCheckRight.is_colliding():
		return -1
	elif direction == 0 and target != null:
		return sign(position.direction_to(target).x)
	else:
		return direction

func trampled(trampler):
	"""被踩踏"""
	set_state(DEAD)
	if trampler.has_method("bounce"):
		trampler.bounce(-600)

func _on_HitBox_body_entered(body):
	"""玩家碰撞Hitbox"""
	if body.has_method("take_damage"):
		var bounce_force = body.position - self.position
		bounce_force = bounce_force.normalized() * 600
		body.take_damage(40, bounce_force)
		velocity = -bounce_force * 2
		set_state(IDLE)

func _on_DetectingBox_body_entered(body):
	"""玩家进入感知区域"""
	if body is Player:
		player = body
		target = body.position
		set_state(ASSAULT)

func _on_DetectingBox_body_exited(body):
	"""玩家退出感知区域"""
	if body is Player:
		player = null
		set_state(WALK)

func _on_Tween_tween_completed(object, key):
	if object == AnimatedSprite and key == ":modulate" and state == DEAD:
		queue_free()
