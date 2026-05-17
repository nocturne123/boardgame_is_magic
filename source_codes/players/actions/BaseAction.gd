class_name BaseAction extends Node

signal action_info(message: String)

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
    # 向战斗日志输出执行信息
    var info := _get_action_info()
    if not info.is_empty():
        action_info.emit(info)

## 由子类重写，返回本次 action 执行的中文描述。
func _get_action_info() -> String:
    return ""
