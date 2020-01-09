extends KinematicBody2D

const FLOOR_NORMAL = Vector2.UP

var gravity = 3800
var jump_force = -1200
var max_speed = 400
var velocity = Vector2(0, 0)
var is_hurt = false

onready var AnimatedSprite = $AnimatedSprite
onready var AudioStreamPlayer = $AudioStreamPlayer
onready var AnimationPlayer = $AnimationPlayer
onready var RayCasts = $RayCasts

func _ready():
	set_camera_limits()

func set_camera_limits():
	"""设置摄像机范围限制"""
	# 获取父节点中包含的TileMap节点
	var tile_map = $"../TileMap" as TileMap
	if tile_map == null:
		print_debug("没有找到关卡中的TileMap节点")
		return
	# 获取TileMap范围与瓦片大小
	var rect = tile_map.get_used_rect()
	var cell_size = tile_map.cell_size
	print_debug(rect.end)
	# 给相机设置范围限制
	var camera = $Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = rect.end.x * cell_size.x
	camera.limit_bottom = rect.end.y * cell_size.y

func _physics_process(delta):
	# 水平方向运动
	var direction = 0
	var lerp_weight = 0.2	# 速度插值权重
	if not is_hurt:
		# 获取水平方向输入
		direction = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	else:
		lerp_weight = 0.09
	# 使用插值函数计算速度
	velocity.x = lerp(velocity.x, direction * max_speed, lerp_weight)
	# 动画
	if is_hurt:
		AnimatedSprite.play("hurt")	# 播放受击动画
	elif direction != 0:
		AnimatedSprite.flip_h = direction < 0 # 方向为负则翻转
		AnimatedSprite.play("walk")	# 播放行走动画
	else:
		AnimatedSprite.play("idle")	# 播放空闲动画
	
	# 竖直方向运动
	if not is_hurt:
		if is_on_floor():
			# 位于地面，获取跳跃输入
			if Input.is_action_just_pressed("ui_up"):
				velocity.y = jump_force
				# 随机范围音高
				AudioStreamPlayer.pitch_scale = rand_range(0.7, 1)
				AudioStreamPlayer.play() # 播放跳跃音效
		else:
			AnimatedSprite.play("jump")	# 播放跳跃动画
	# 施加重力
	velocity.y += gravity * delta
	
	check_bounce()	# 检测脚底是否有弹跳物
	velocity = move_and_slide(velocity, FLOOR_NORMAL)

func check_bounce():
	# 检查脚底射线是否有碰撞
	for ray in RayCasts.get_children():
		if ray.is_colliding():
			var collider = ray.get_collider()
			if collider.has_method("trampled"):
				collider.trampled(self)
				break

func bounce(speed):
	velocity.y = speed

func take_damage(damage, bounce_force = Vector2.ZERO):
	"""受到伤害，damage为伤害数值，bounce_force为受到的作用力"""
	is_hurt = true
	velocity += bounce_force
	# 播放闪烁动画
	AnimationPlayer.play("hurt")
	yield(get_tree().create_timer(0.6), "timeout")
	# 停止闪烁动画
	AnimationPlayer.seek(0, true)
	AnimationPlayer.stop()
	is_hurt = false
