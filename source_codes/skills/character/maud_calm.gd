class_name MaudCalm extends SkillData

## 冷静（灰琪角色技能）：掷骰时掷两次，选择一个作为结果。
## 对陆马种族技能判定无效。
##
## 替换 RollDiceExecute 为 CalmRollExecute。
## CalmRollExecute 内部临时恢复标准链跑两次 RollDiceEntry → RollDiceExecute，
## 然后暂停让 HUD 选择骰子。

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

var _saved_dice_next: BaseAction = null

func on_attach(player: Player) -> void:
    if is_disabled():
        return
    var tree = _get_action_tree(player)
    if tree == null:
        return
    var calm = _create_action_node(tree,
        "res://source_codes/skills/actions/calm_roll_execute.gd", "CalmRollExecute")

    # 保存 RollDiceEntry 的原始 next_action，替换为 CalmRollExecute
    _saved_dice_next = tree.roll_dice_entry.next_action
    tree.roll_dice_entry.next_action = calm

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    if tree != null and _saved_dice_next:
        tree.roll_dice_entry.next_action = _saved_dice_next
    super.on_detach(player)
