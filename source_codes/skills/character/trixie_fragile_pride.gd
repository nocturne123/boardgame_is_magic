class_name TrixieFragilePride extends SkillData

## 易碎骄傲（特丽克西角色技能）：
## 当 D6 判定失败（结果 < 3）时，受到 1 点心理伤害。
## 通过插入 DiceFailureTrigger 到骰子链末端实现。

func _init() -> void:
    id = "trixie_fragile_pride"
    nice_name = "易碎骄傲"
    category = SkillData.Category.Character
    skill_type = SkillData.SkillType.Passive
    description = "当你的 D6 判定失败时，你受到 1 点心理伤害。"
    ignore_distance = false
    range = -1
    cooldown = 0
    max_uses_per_turn = 0
    needs_target = false


func on_attach(player: Player) -> void:
    if is_disabled():
        return
    var tree = _get_action_tree(player)
    if tree == null:
        return
    var trigger: DiceFailureTrigger = _create_action_node(tree,
        "res://source_codes/skills/actions/dice_failure_trigger.gd",
        "DiceFailureTrigger") as DiceFailureTrigger

    # 找到骰子链末端，插入 DiceFailureTrigger（R15 保留下游）
    var end_node: BaseAction = tree.roll_dice_entry
    while end_node.next_action != null and end_node.next_action != trigger:
        end_node = end_node.next_action
    trigger.next_action = end_node.next_action
    end_node.next_action = trigger

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    if tree != null:
        var trigger = tree.get_node_or_null("DiceFailureTrigger")
        if trigger:
            # 找到指向 trigger 的节点，跳过 trigger（R15）
            var node: BaseAction = tree.roll_dice_entry
            while node.next_action != null and node.next_action != trigger:
                node = node.next_action
            if node.next_action == trigger:
                node.next_action = trigger.next_action
    super.on_detach(player)
