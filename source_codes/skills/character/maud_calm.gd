class_name MaudCalm extends SkillData

## 冷静（灰琪角色技能）：掷骰时掷两次，选择一个作为结果。
## 对陆马种族技能判定无效。

func _init() -> void:
    id = "maud_calm"
    nice_name = "冷静"
    category = SkillData.Category.Character
    skill_type = SkillData.SkillType.Passive
    description = "在自己掷骰子时掷两次，然后选择一个作为结果（对陆马种族技能判定无效）"
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
    var calm = _create_action_node(tree,
        "res://source_codes/skills/actions/calm_roll_execute.gd", "CalmRollExecute")
    # 替换: RollDiceEntry → CalmRollExecute（绕过默认 RollDiceExecute）
    tree.roll_dice_entry.next_action = calm

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    if tree != null:
        # 恢复: RollDiceEntry → RollDiceExecute
        tree.roll_dice_entry.next_action = tree.roll_dice_execute
    super.on_detach(player)
