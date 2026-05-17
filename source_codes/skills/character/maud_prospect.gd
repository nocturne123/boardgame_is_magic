class_name MaudProspect extends SkillData

## 勘探（灰琪角色技能）：摸牌阶段少摸1张，翻看1张牌，
## 手牌有同名牌则抽它和下一张，否则 +1 护甲。

func _init() -> void:
    id = "maud_prospect"
    nice_name = "勘探"
    category = SkillData.Category.Character
    skill_type = SkillData.SkillType.Active
    description = "摸牌阶段少摸一张牌，翻看一张牌：手牌有同名牌则抽取它和下一张；没有则获得一点护甲"
    ignore_distance = false
    range = -1
    cooldown = 0
    max_uses_per_turn = 1
    needs_target = false

func on_attach(player: Player) -> void:
    if is_disabled():
        return
    var tree = _get_action_tree(player)
    if tree == null:
        return
    var entry = _create_action_node(tree,
        "res://source_codes/skills/actions/prospect_entry.gd", "ProspectEntry")
    var effect = _create_action_node(tree,
        "res://source_codes/skills/actions/prospect_effect.gd", "ProspectEffect")
    # 插入: TurnStart → ProspectEntry → DrawCard → ProspectEffect → null
    tree.turn_start.next_action = entry
    entry.next_action = tree.draw_card
    tree.draw_card.next_action = effect

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    if tree != null:
        # 恢复: TurnStart → DrawCard → null
        tree.turn_start.next_action = tree.draw_card
        tree.draw_card.next_action = null
    super.on_detach(player)
