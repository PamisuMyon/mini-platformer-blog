extends KinematicBody2D
class_name Player

const FLOOR_NORMAL = Vector2.UP

# 暴露给编辑器的属性
export (Vector2) var max_speed_default := Vector2(400, 3800)
export (Vector2) var acceleration_default := Vector2(240, 3800)
export (Vector2) var acceleration_rate_default := Vector2(1.5, 1)
export (float) var jump_force_default := -1200.0
export (float) var slide_time_default := 0.6
export (float) var friction_ground := 0.2
export (float) var friction_air := 0.05
export (float) var max_hp_default := 100.0

onready var max_speed := max_speed_default	# 最大速度
onready var acceleration := acceleration_default	# 加速度
onready var acceleration_rate := acceleration_rate_default	# 加速度变化量
onready var jump_force := jump_force_default	# 跳跃作用力
onready var friction := friction_ground	# 摩擦力，用于减速
onready var max_hp := max_hp_default	# 最大生命值
onready var hp := max_hp	# 当前生命值

var velocity := Vector2(0, 0)	# 当前速度
onready var acc := acceleration	# 当前加速度
var direction := 0.0	# 当前方向
var gravity_ratio := 1.0	# 重力比率，用于控制不同状态下所受重力
var state_machine: PlayerStateMachine	# 状态机

onready var AnimatedSprite = $AnimatedSprite
onready var AudioStreamPlayer = $AudioStreamPlayer
onready var AnimationPlayer = $AnimationPlayer
onready var RayCasts = $RayCasts

func _ready():
	set_camera_limits()	# 初始化摄像机限制范围
	# 初始化状态机
	state_machine = PlayerStateMachine.new(self)
	state_machine.set_state_deferred(PlayerStateMachine.IDLE)

func _physics_process(delta):
	# 调用状态机处理逻辑
	state_machine.process(delta)

func process_velocity(delta):
	"""计算速度"""
	# 水平方向
	if direction != 0:
		# 变加速运动
		velocity.x += direction * acc.x * delta
		acc.x *= acceleration_rate.x
		velocity.x = clamp(velocity.x, -max_speed.x, max_speed.x)
	else:
		# 还原加速度，以摩擦力做减速运动
		acc.x = acceleration.x
		velocity.x = lerp(velocity.x, 0, friction)
		
	# 竖直方向
	velocity.y += acc.y * gravity_ratio * delta
	velocity.y = clamp(velocity.y, -max_speed.y, max_speed.y)

func process_movement(delta):
	"""移动"""
	velocity = move_and_slide(velocity, FLOOR_NORMAL)

func check_bounce():
	"""检测弹跳"""
	# 检查脚底射线是否有碰撞
	for ray in RayCasts.get_children():
		if ray.is_colliding():
			var collider = ray.get_collider()
			if collider.has_method("trampled"):
				collider.trampled(self)
				break

func bounce(speed):
	"""以给定速度弹跳"""
	velocity.y = speed

func take_damage(damage, bounce_force = Vector2.ZERO):
	"""受到伤害，damage为伤害数值，bounce_force为受到的作用力"""
	velocity = bounce_force
	hp -= damage
	if hp > 0:
		# 受击
		state_machine.set_state(PlayerStateMachine.HURT)
		yield(get_tree().create_timer(0.6), "timeout")
		state_machine.set_state(PlayerStateMachine.IDLE)
	else:
		# 死亡
		state_machine.set_state(PlayerStateMachine.DEAD)
		set_collision_layer_bit(1, false)
		set_collision_mask_bit(2, false)
		set_collision_mask_bit(3, false)

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
	# 给相机设置范围限制
	var camera = $Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = rect.end.x * cell_size.x
	camera.limit_bottom = rect.end.y * cell_size.y


class PlayerStateMachine extends StateMachine:
	"""玩家状态机"""
	
	# 状态：静止、行走、跳跃、受击、滑铲、死亡
	enum {IDLE, WALK, JUMP, HURT, SLIDE, DEAD} 
	var p: Player = null	# 引用Player实例
	var state_duration = 0	# 状态持续时间，用于状态定时切换
	
	func _init(player: Player):
		"""构造函数"""
		p = player
		add_state(IDLE)
		add_state(WALK)
		add_state(JUMP)
		add_state(HURT)
		add_state(SLIDE)
		add_state(DEAD)
		set_state_deferred(IDLE)
	
	func _do_actions(delta):
		"""执行当前状态行为"""
		match state:
			IDLE, WALK:
				_handle_input(delta)
				if Input.is_action_just_pressed("ui_up"):
					p.velocity.y += p.jump_force
				p.check_bounce()
			JUMP:
				_handle_input(delta)
				p.check_bounce()
			HURT:
				p.direction = 0
				if p.is_on_floor():
					p.friction = p.friction_ground
				else:
					p.friction = p.friction_air
			SLIDE:
				_handle_input(delta)
				if Input.is_action_just_pressed("ui_up"):
					p.velocity.y += p.jump_force
				state_duration += delta	# 累加状态停留时间
			DEAD:
				p.direction = 0
		_sprite_flip()	# 动画翻转
		p.process_velocity(delta)	# 计算速度
		p.process_movement(delta)	# 移动
	
	func _check_conditions(delta):
		"""检查当前状态转移条件，返回需要转移到的状态"""
		match state:
			IDLE:
				if p.is_on_floor():
					if p.direction != 0:
						return WALK	# 处于地面且有移动方向则为行走状态
				else:
					return JUMP	# 不处于地面则为跳跃状态
			WALK:
				if p.is_on_floor():
					if p.direction == 0:
						return IDLE
					elif Input.is_action_just_pressed("ui_down"):
						return SLIDE	# 行走时按下↓则为滑铲状态
				else:
					return JUMP
			JUMP:
				if p.is_on_floor():
					if p.direction == 0:
						return IDLE
					else:
						return WALK
			SLIDE:
				# 滑铲状态，松开方向键、改变方向、持续时间到将退出状态
				if p.is_on_floor():
					if p.direction == 0:
						return IDLE
					elif sign(p.direction) != sign(p.velocity.x):
						return WALK
					elif state_duration >= p.slide_time_default:
						return WALK
				else:
					return JUMP
		
	func _enter_state(state, old_state):
		"""进入状态"""
		match state:
			IDLE:
				# 调整重力比率及摩擦力
				p.gravity_ratio = 0.1
				p.friction = p.friction_ground
				p.AnimatedSprite.play("idle")
			WALK:
				p.gravity_ratio = 0.1
				p.friction = p.friction_ground
				p.AnimatedSprite.play("walk")
			JUMP:
				# 空中受到完全重力影响
				p.gravity_ratio = 1.0
				p.friction = p.friction_air
				if p.velocity.y < 0:
					p.AnimatedSprite.play("jump")
				else:
					p.AnimatedSprite.play("fall")
			HURT:
				p.gravity_ratio = 1.0
				p.AnimatedSprite.play("hurt")
				p.AnimationPlayer.play("hurt")	# 播放受伤闪烁动画
			SLIDE:
				state_duration = 0	# 记录状态停留时间
				p.gravity_ratio = 0.1
				p.friction = p.friction_air
				p.AnimatedSprite.play("slide")
			DEAD:
				p.gravity_ratio = 1.0
				p.AnimatedSprite.play("dead")
				p.AnimationPlayer.play("disappear")	# 播放消失动画
	
	func _exit_state(state, new_state):
		"""退出状态"""
		match state:
			HURT:
				# 停止受伤闪烁动画播放
				p.AnimationPlayer.seek(0, true)
				p.AnimationPlayer.stop()
	
	func set_state(new_state):
		# 重写set_state函数，避免死亡后进入其他状态
		if state == DEAD: return
		.set_state(new_state)	# 调用父类函数
	
	func _handle_input(delta):
		"""通用输入处理"""
		var direction = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if p.direction != direction:
			# 切换方向时加速度要重置
			p.acc = p.acceleration_default
		p.direction = direction
	
	func _sprite_flip():
		"""通用Sprite翻转"""
		if p.direction > 0:
			p.AnimatedSprite.flip_h = false
		elif p.direction < 0:
			p.AnimatedSprite.flip_h = true
