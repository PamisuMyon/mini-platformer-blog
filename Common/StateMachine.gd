extends Node
class_name StateMachine

var states := []	# 包含所有状态的数组
var state: int	# 当前状态
var previous_state: int	# 上一个状态

func process(delta):
	"""状态机逻辑，预期在每一帧执行"""
	if state != null:
		# 执行当前状态行为
		_do_actions(delta)
		# 检查是否符合状态转移条件
		var new_state = _check_conditions(delta)
		if new_state != null:
			set_state(new_state)

func _do_actions(delta):
	"""执行当前状态行为"""
	pass

func _check_conditions(delta):
	"""检查当前状态转移条件，返回需要转移到的状态"""
	pass
	
func _enter_state(state, old_state):
	"""进入状态"""
	pass

func _exit_state(state, new_state):
	"""退出状态"""
	pass

func set_state(new_state):
	"""设置当前状态"""
	if states.has(new_state):
		previous_state = state
		state = states[new_state]
		if previous_state != null:
			_exit_state(previous_state, state)
		if state != null:
			_enter_state(state, previous_state)

func set_state_deferred(new_state):
	"""设置当前状态的延迟调用包装"""
	call_deferred("set_state", new_state)

func add_state(new_state):
	"""新增状态"""
	states.append(new_state)