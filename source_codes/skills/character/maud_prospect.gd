class_name MaudProspect extends SkillData

## 勘探（灰琪角色技能）：摸牌阶段少摸1张，翻看1张牌，
## 手牌有同名牌则抽它和下一张，否则 +1 护甲。
##
## 插入规则：保存 TurnStart 和 DrawCard 的原始 next_action，
## 在它们之间插入 ProspectEntry/ProspectEffect，on_detach 时恢复原始链。
## 这样与其他修改 TurnStart 链的技能（未来）兼容。

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

var _saved_turn_next: BaseAction = null
var _saved_draw_next: BaseAction = null

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

    # 保存当前链状态
    _saved_turn_next = tree.turn_start.next_action
    _saved_draw_next = tree.draw_card.next_action

    # 插入 ProspectEntry 在 TurnStart 和它的原 next 之间
    tree.turn_start.next_action = entry
    entry.next_action = _saved_turn_next

    # 插入 ProspectEffect 在 DrawCard 和它的原 next 之间
    tree.draw_card.next_action = effect
    effect.next_action = _saved_draw_next

func on_detach(player: Player) -> void:
    var tree = _get_action_tree(player)
    if tree != null:
        # 恢复原始链
        if _saved_turn_next:
            tree.turn_start.next_action = _saved_turn_next
        if _saved_draw_next:
            tree.draw_card.next_action = _saved_draw_next
    super.on_detach(player)
