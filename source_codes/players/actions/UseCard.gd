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

    # 1. 确定执行子节点
    var child: BaseAction = null
    if card is BaseEquipment:
        child = get_node_or_null("UseEquipment") as BaseAction
    elif card is BaseEffect:
        child = get_node_or_null("UseEffect") as BaseAction
    elif card.type == "Event":
        child = get_node_or_null("UseEventCard") as BaseAction
    else:
        child = get_node_or_null("UseBaseplay") as BaseAction

    if child == null:
        return
    child.player = player
    child.card = card
    child.target = target

    # 2. 判断是否需要距离校验
    var need_range := false
    var check_range := 1
    if card.type == "Attack":
        need_range = true
        check_range = _calc_attack_range(player)
    elif card.needs_range_check:
        need_range = true
        check_range = card.effective_range

    # 3. 蛮力掷骰（攻击牌专属，在 RangeCheck 之后插入）
    if card.type == "Attack" and has_meta("strength_entry"):
        var skill = _get_strength_skill(player)
        if skill and skill.enabled:
            var entry = get_meta("strength_entry")
            var execute = get_meta("strength_execute")
            execute.next_action = child        # StrengthRollExecute → UseBaseplay
            if need_range:
                var rc = _get_range_check()
                if rc:
                    rc.source = player; rc.target = target; rc.max_range = check_range
                    rc.next_action = entry     # RangeCheck → StrengthRollEntry
                    next_action = rc            # UseCard → RangeCheck
                else:
                    next_action = entry
            else:
                next_action = entry
            return

    # 4. 链条路由
    if need_range:
        var rc = _get_range_check()
        if rc:
            rc.source = player
            rc.target = target
            rc.max_range = check_range
            rc.next_action = child
            next_action = rc
            return
    next_action = child

func _get_range_check() -> RangeCheck:
    var tree := get_parent() as ActionTree
    if tree:
        return tree.get_node_or_null("RangeCheck") as RangeCheck
    return null

func _calc_attack_range(p: Player) -> int:
    var r := p.attack_range
    r += p.get_meta("attack_range_bonus", 0)
    var tm = p.get_meta("terrain_manager")
    if tm:
        r += tm.get_attack_range_mod(p)
    return max(r, 1)

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
