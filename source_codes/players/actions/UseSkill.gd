class_name UseSkill extends BaseAction

## 主动技能统一入口。HudBattle 设置 skill / target / card_to_discard 后调用 chain_of_actions(use_skill)。
## inform_next_action 按需路由到 RangeCheck → 技能专属 action 节点。

var skill: SkillData = null
var target: Player = null
var card_to_discard: CardData = null

func take_action() -> void:
    pass

func inform_next_action() -> void:
    if skill == null:
        return
    var tree := get_parent() as ActionTree
    if tree == null:
        return
    var action := skill.get_action_node(tree)
    if action == null:
        return

    action.player = player
    action.target = target
    if skill.needs_card_discard and card_to_discard:
        action.card_to_discard = card_to_discard
    # 回传 skill 引用供 CrystalShineExecute 等使用
    if action.get("skill") != null:
        action.skill = skill

    # 距离校验
    if skill.needs_target and not skill.ignore_distance and skill.range != -1:
        var rc := tree.get_node_or_null("RangeCheck") as RangeCheck
        if rc:
            rc.source = player
            rc.target = target
            rc.max_range = skill.range
            rc.next_action = action
            next_action = rc
            return
    next_action = action

func reset_property() -> void:
    skill = null
    target = null
    card_to_discard = null

func _get_action_info() -> String:
    if skill == null:
        return ""
    var tname := target.player_name if target else "?"
    return "%s 使用了技能 [%s] → %s" % [player.player_name, skill.nice_name, tname]
