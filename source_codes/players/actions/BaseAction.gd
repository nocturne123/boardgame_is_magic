class_name BaseAction extends Node

var next_action = null
var extra_function = null
@onready var player = get_parent().get_parent()

func take_action():
	pass

func imform_next_action():
	pass
	
func reset_property():
	pass

func trigger():
	#当有额外的功能时，将node自己传进去调用
	#这里不重置extra_function为null，
	#由添加extra_func的节点或功能管理其周期
	if extra_function != null:
		extra_function.call(self)
		#extra_function = null
	else :
		take_action()
		reset_property()
