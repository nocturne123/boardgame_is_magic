class_name UseCard extends BaseAction

## 用牌调度器：根据卡牌类型分发到 UseEquipment / UseEffect / UseBaseplay。
## HudBattle 设置 card 和 target 后调用 chain_of_actions(use_card)。
## 三个子节点在 _ready() 中动态创建，无需场景预置。

var card: CardData = null
var target: Player = null

func _ready() -> void:
    # 动态创建四个子动作节点
    var eq := UseEquipment.new()
    eq.name = "UseEquipment"
    add_child(eq)

    var eff := UseEffect.new()
    eff.name = "UseEffect"
    add_child(eff)

    var bp := UseBaseplay.new()
    bp.name = "UseBaseplay"
    add_child(bp)

    var ev := UseEventCard.new()
    ev.name = "UseEventCard"
    add_child(ev)

func take_action() -> void:
    pass  # 调度器不做实际逻辑

func inform_next_action() -> void:
    if card == null:
        return

    var child: BaseAction = null
    if card is BaseEquipment:
        child = get_node_or_null("UseEquipment") as BaseAction
    elif card is BaseEffect:
        child = get_node_or_null("UseEffect") as BaseAction
    elif card.type == "Event":
        # 事件手牌（魔法对决等）路由到 UseEventCard
        child = get_node_or_null("UseEventCard") as BaseAction
    else:
        child = get_node_or_null("UseBaseplay") as BaseAction

    if child:
        child.player = player
        child.card = card
        child.target = target

        # 蛮力：攻击牌掷骰判定
        if card.type == "Attack" and has_meta("strength_entry"):
            var skill = _get_strength_skill(player)
            if skill and skill.enabled:
                var entry = get_meta("strength_entry")
                var execute = get_meta("strength_execute")
                execute.next_action = child   # 掷骰后继续 UseBaseplay
                next_action = entry
                return
        next_action = child

func _get_strength_skill(p: Player) -> SkillData:
    for s in p.skills:
        if s.id == "earth_pony_strength":
            return s
    return null

func reset_property() -> void:
    card = null
    target = null


func _get_action_info() -> String:
    if card == null:
        return ""
    return "%s 使用了 [%s]" % [player.player_name, card.nice_name]
