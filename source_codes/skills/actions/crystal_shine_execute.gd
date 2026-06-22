class_name CrystalShineExecute extends BaseAction

## 水晶洗礼执行动作：
## 1. 弃置一张手牌（代价）
## 2. 为目标添加一个水晶洗礼印记
##
## 由 HudBattle 在玩家选牌 + 点技能 + 选目标后触发。

var target: Player = null
var card_to_discard: CardData = null
var skill: SunburstCristallShine = null

func take_action() -> void:
	if player == null or target == null or card_to_discard == null:
		return
	# 弃置手牌
	player.remove_card_from_hand(card_to_discard)
	if player.card_manager:
		player.card_manager.receive_into_discard(card_to_discard)
	# 放置印记
	if skill and not skill.is_disabled():
		skill.add_mark(target)

func reset_property() -> void:
	target = null
	card_to_discard = null
	skill = null


func _get_action_info() -> String:
	if target == null:
		return ""
	return "%s 对 %s 施加了水晶洗礼印记" % [player.player_name, target.player_name]
