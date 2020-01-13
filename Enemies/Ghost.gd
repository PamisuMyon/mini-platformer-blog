extends KinematicBody2D
class_name Ghost

var max_speed_normal = 100	# 正常速度
var max_speed_assault = 200	# 突袭速度
var max_speed = max_speed_normal
var velocity := Vector2()
var origin_position: Vector2	# 初始位置
var active_range := Vector2(500, 50)	# 活动范围x,y
var target: Vector2	# 目标
var player: Player	# 处于检测范围内的玩家
var state_machine: GhostStateMachine	# 状态机

onready var AnimatedSprite = $AnimatedSprite

func _ready():
	# 记录原始位置，初始化状态机
	origin_position = position
	state_machine = GhostStateMachine.new(self)
	state_machine.set_state_deferred(GhostStateMachine.IDLE)
	
func _physics_process(delta):
	state_machine.process(delta)
	
func process_movement(delta):
	velocity = move_and_slide(velocity)

func _on_HitBox_body_entered(body):
	"""玩家碰撞Hitbox"""
	if body.has_method("take_damage"):
		var bounce_force = body.position - self.position
		bounce_force = bounce_force.normalized() * 600
		body.take_damage(80, bounce_force)

func _on_DetectingBox_body_entered(body):
	"""玩家进入感知区域"""
	if body is Player:
		player = body
		target = body.position
		state_machine.set_state(GhostStateMachine.ASSAULT)
	
func _on_DetectingBox_body_exited(body):
	"""玩家退出感知区域"""
	if body is Player:
		player = null
		state_machine.set_state(GhostStateMachine.WALK)


class GhostStateMachine extends StateMachine:
	"""鬼魂状态机"""
	
	enum {IDLE, WALK, ASSAULT}	# 状态：静止、行走、突袭
	var p: Ghost	# 鬼魂实例引用
	var state_duration = 0	# 当前状态停留时间，用于状态定时切换
	var state_stay = 0	# 当前状态允许的最大停留时间
	
	func _init(ghost: Ghost):
		p = ghost
		add_state(IDLE)
		add_state(WALK)
		add_state(ASSAULT)
	
	func _do_actions(delta):
		"""执行当前状态行为"""
		match state:
			IDLE:
				# 累加状态停留时间
				state_duration += delta
			WALK, ASSAULT:
				# 向目标前进
				var direction = p.position.direction_to(p.target)
				# 使用线性插值计算速度
				p.velocity = p.velocity.linear_interpolate(direction * p.max_speed, 0.05)
				p.process_movement(delta)
				# 翻转动画
				if direction.x > 0:
					p.AnimatedSprite.flip_h = true
				elif direction.x < 0:
					p.AnimatedSprite.flip_h = false
	
	func _check_conditions(delta):
		"""检查当前状态转移条件，返回需要转移到的状态"""
		match state:
			IDLE:
				# 超出停留时间则切换至移动状态
				if state_duration > state_stay:
					return WALK
			WALK:
				# 到达目的地则停止
				if p.position.distance_squared_to(p.target) < 9:
					return IDLE
			ASSAULT:
				# 到达目的地，如果玩家仍在感知范围内，则继续突袭
				if p.position.distance_squared_to(p.target) < 9:
					if p.player != null:
						p.target = p.player.position
					else:
						return IDLE
		
	func _enter_state(state, old_state):
		"""进入状态"""
		match state:
			IDLE:
				# 静止状态，随机持续时间
				p.AnimatedSprite.play("normal")
				p.velocity = Vector2.ZERO
				state_duration = 0
				state_stay = rand_range(1, 2)
			WALK:
				# 移动状态，在活动范围内移动
				p.max_speed = p.max_speed_normal
				p.AnimatedSprite.play("normal")
				var tar_x
				if p.position.x > p.origin_position.x:
					tar_x = p.origin_position.x - p.active_range.x
				else:
					tar_x = p.origin_position.x + p.active_range.x
				var tar_y = p.origin_position.y + rand_range(-p.active_range.y, p.active_range.y)
				p.target = Vector2(tar_x, tar_y)
			ASSAULT:
				# 突袭状态
				p.max_speed = p.max_speed_assault
				p.AnimatedSprite.play("assault")
