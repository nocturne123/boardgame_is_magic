class_name BaseAction extends Node

var next_action = null
var extra_function = null
## 设为 true 时暂停 chain，等 HUD 交互完成后调用 ActionTree.resume_chain() 恢复。
var waiting: bool = false
@onready var player = get_parent().get_parent()

func take_action():
    pass

func inform_next_action():
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

## 由子类重写，返回本次 action 执行的中文描述。
## 由 ActionTree 在 trigger() 后统一调用并发射 action_executed 信号。
func _get_action_info() -> String:
    return ""
