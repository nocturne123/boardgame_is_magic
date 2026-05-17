class_name ProspectEntry extends BaseAction

## 勘探入口：TurnStart 之后、DrawCard 之前。
## 暂停 chain 等 HUD 询问玩家是否使用勘探。
## 激活时调整 DrawCard 抽牌数 -1。

var prospect_activated: bool = false

func take_action():
    waiting = true

func inform_next_action():
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
