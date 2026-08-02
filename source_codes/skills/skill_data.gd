class_name SkillData extends Resource

## 技能基类。种族技能、角色技能、装备技能均继承此类。
## 技能通过 on_attach / on_detach 修改 Player 的 ActionTree 链条来生效。
## disabled 机制：技能仍在玩家身上，但被禁用，链条恢复默认。

enum Category { Species, Character, Equipment }
enum SkillType { Active, Passive }

@export var id: String = ""
@export var nice_name: String = ""
@export var category: Category = Category.Species
@export var skill_type: SkillType = SkillType.Passive
@export var description: String = ""
@export var ignore_distance: bool = false
@export var range: int = -1           ## -1 = 无限制
@export var cooldown: int = 0
@export var max_uses_per_turn: int = 0
@export var needs_target: bool = false
@export var needs_card_discard: bool = false

## 失效状态：技能仍在 player.skills 中，但链条恢复默认，不生效。
var _disabled: bool = false

## 技能创建的 action 节点引用（供 on_detach 时清理）。
var _inserted_nodes: Array[Node] = []

## 失效状态变更信号，HUD 监听以刷新显示。
signal disabled_changed(disabled: bool)


# ============================================================
# 失效机制
# ============================================================

func is_disabled() -> bool:
    return _disabled

## 设为失效时调用 on_detach 恢复链条；恢复时调用 on_attach 重新修改链条。
func set_disabled(d: bool, player: Player) -> void:
    if d == _disabled:
        return
    _disabled = d
    if d:
        on_detach(player)
    else:
        on_attach(player)
    disabled_changed.emit(d)


# ============================================================
# 生命周期 — 子类重写
# ============================================================

## 挂接到玩家时：修改 ActionTree 链条。由子类重写。
func on_attach(_player: Player) -> void:
    pass

## 卸下或失效时：恢复默认链条，清理插入的节点。由子类重写。
## 子类应先恢复链条，再调用 super.on_detach()。
func on_detach(_player: Player) -> void:
    for node in _inserted_nodes:
        if is_instance_valid(node):
            node.queue_free()
    _inserted_nodes.clear()


## 返回该技能对应的专属 action 节点（子类重写）。
## UseSkill 通过此方法查找要触发的 action 节点，注入参数后执行。
func get_action_node(_tree: ActionTree) -> BaseAction:
    return null


# ============================================================
# 辅助方法
# ============================================================

func _get_action_tree(player: Player) -> ActionTree:
    if player == null:
        return null
    return player.get_node_or_null("ActionTree") as ActionTree

## 创建 action 节点并加入 ActionTree。幂等：同名节点已存在则返回已有的。
func _create_action_node(tree: ActionTree, script_path: String, node_name: String) -> Node:
    var existing := tree.get_node_or_null(node_name)
    if existing:
        return existing
    var scr := load(script_path)
    if scr == null:
        push_error("SkillData: 无法加载脚本: %s" % script_path)
        return null
    var node: Node = scr.new()
    node.name = node_name
    tree.add_child(node)
    _inserted_nodes.append(node)
    return node
