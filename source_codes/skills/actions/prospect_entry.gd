class_name ProspectEntry extends BaseAction

## 勘探入口：TurnStart 之后、DrawCard 之前。
## 暂停 chain 等 HUD 询问玩家是否使用勘探。
## 激活时调整 DrawCard 抽牌数 -1。

var prospect_activated: bool = false

func take_action():
    waiting = true

func inform_next_action():
    # 后续节点（DrawCard / ProspectEffect）需要知道玩家是否选了勘探。
    # 不能依赖 prospect_activated —— ActionTree 会在 inform_next_action 之后
    # 立刻调 reset_property() 把它清零，ProspectEffect 读到时永远是 false。
    var tree := get_parent() as ActionTree
    if tree != null:
        tree.set_meta("prospect_active_this_turn", prospect_activated)
    if prospect_activated and next_action and next_action.get("draw_num") != null:
        next_action.draw_num = max(player.draw_stage_card_number - 1, 0)
    elif next_action and next_action.get("draw_num") != null:
        next_action.draw_num = player.draw_stage_card_number

func reset_property():
    prospect_activated = false


func _get_action_info() -> String:
    if prospect_activated:
        return "%s 发动了勘探技能" % player.player_name
    return ""
