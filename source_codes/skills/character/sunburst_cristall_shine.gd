class_name SunburstCristallShine extends SkillData

## 水晶洗礼（日光耀耀角色技能）：
## 每回合可以弃置一张牌，为其他角色添加水晶洗礼印记。
## 当该角色有体力恢复时，移除所有印记，造成等量的真实伤害。
## 技能失效时，所有印记一起失效（清除）。
##
## 实现方式：
## - 印记数据：目标 player 的 meta "crystal_marks" = 印记数量
## - 印记 action：首次 add_mark 时在目标的 ActionTree 中动态创建
##   CrystalMarkTrigger 节点，插入到 HealExecute 之后
## - 技能失效时：移除所有目标树上的 CrystalMarkTrigger 节点，
##   恢复 HealExecute → null，清除所有 meta
## - 主动触发：通过 UseSkill 节点 → CrystalShineExecute（on_attach 创建）

const _CrystalMarkTriggerScript = preload("res://source_codes/players/actions/CrystalMarkTrigger.gd")

## 已标记的目标玩家列表（用于 on_detach 时清理）
var _marked_targets: Array[Player] = []

## on_attach 创建的 CrystalShineExecute 节点引用
var _crystal_action: CrystalShineExecute = null


func _init() -> void:
    id = "sunburst_cristall_shine"
    nice_name = "水晶洗礼"
    category = SkillData.Category.Character
    skill_type = SkillData.SkillType.Active
    description = "每回合你可以弃置一张牌，为其他一个角色添加一个水晶洗礼印记。当该角色有体力恢复时，移除所有的印记，造成等量的真实伤害。"
    ignore_distance = true
    range = -1
    cooldown = 0
    max_uses_per_turn = 0
    needs_target = true
    needs_card_discard = true


func on_attach(player: Player) -> void:
    var tree = _get_action_tree(player)
    if tree == null:
        return
    _crystal_action = _create_action_node(tree,
        "res://source_codes/skills/actions/crystal_shine_execute.gd", "CrystalShineExecute")

func get_action_node(_tree: ActionTree) -> BaseAction:
    return _crystal_action

func on_detach(player: Player) -> void:
    # 技能失效时，所有印记一起失效
    clear_all_marks()
    super.on_detach(player)


# ============================================================
# 印记管理
# ============================================================

## 为目标添加一个印记。
## 首次添加时在目标的 ActionTree 中插入 CrystalMarkTrigger 节点。
func add_mark(target: Player) -> void:
    if target == null:
        return
    var count: int = target.get_meta("crystal_marks", 0)
    target.set_meta("crystal_marks", count + 1)
    # 首次标记：在目标树上插入 CrystalMarkTrigger
    if not _marked_targets.has(target):
        _marked_targets.append(target)
        _insert_crystal_trigger(target)


## 清除所有印记（技能失效时调用）。
## 移除每个目标树上的 CrystalMarkTrigger 节点，恢复默认链条。
func clear_all_marks() -> void:
    for target in _marked_targets:
        if is_instance_valid(target):
            target.remove_meta("crystal_marks")
            _remove_crystal_trigger(target)
    _marked_targets.clear()


# ============================================================
# 动态节点管理
# ============================================================

## 在目标的 ActionTree 中插入 CrystalMarkTrigger，接在 HealExecute 之后
func _insert_crystal_trigger(target: Player) -> void:
    var tree = target.get_node_or_null("ActionTree")
    if tree == null:
        return
    var heal_execute = tree.get_node_or_null("HealExecute")
    if heal_execute == null:
        return
    # 幂等：已存在则跳过
    if tree.get_node_or_null("CrystalMarkTrigger") != null:
        return
    var node: Node = _CrystalMarkTriggerScript.new()
    node.name = "CrystalMarkTrigger"
    tree.add_child(node)
    # 插入链条：保存 HealExecute 的原 next，CrystalMarkTrigger 接在中间
    node.next_action = heal_execute.next_action
    heal_execute.next_action = node


## 移除目标树上的 CrystalMarkTrigger，恢复 HealExecute → null
func _remove_crystal_trigger(target: Player) -> void:
    var tree = target.get_node_or_null("ActionTree")
    if tree == null:
        return
    var node = tree.get_node_or_null("CrystalMarkTrigger")
    if node == null:
        return
    var heal_execute = tree.get_node_or_null("HealExecute")
    if heal_execute:
        # 恢复：绕过 CrystalMarkTrigger，接回它后面的节点
        heal_execute.next_action = node.next_action
    node.queue_free()
