class_name UseEquipment extends BaseAction

## UseCard 的子节点：处理装备牌（Weapon / Armor / Element）。
## 参数由 UseCard.inform_next_action() 注入。

var card: CardData = null
var target: Player = null
var _old_card_nice: String = ""
var _new_info: String = ""
var _failed: bool = false

func take_action() -> void:
    _failed = false
    if card == null:
        return

    var eq := card as BaseEquipment
    if eq == null:
        # 非装备牌不该走到这里
        _failed = true
        return

    # 正常装备：execute() 内部处理装备逻辑 + 对旧牌触发 on_unequip + 设置 replaced_old_card
    # （原先的「收藏品占用检查」分支已删除：它比较的两个槽位类型恒相等，永远不可达，
    #   且其分支会把打出的卡牌直接丢进弃牌堆——打出的是收藏品时会被误弃。）
    var ok: bool = card.execute(player, target, player.card_manager)
    if not ok:
        # 装备失败：卡牌留在手里，不移出、不进弃牌堆
        _failed = true
        return
    player.remove_card_from_hand(card)

    # 装备成功，记录日志信息
    _new_info = _card_info(card)
    var old_card: CardData = eq.replaced_old_card
    if old_card != null:
        _old_card_nice = old_card.nice_name
        if player.is_collection_item(old_card.identity):
            # R9：收藏品被顶替 → 移入 Collection 槽，不进弃牌堆
            player._add_to_slot(Player.EquipmentSlotType.Collection, old_card)
        elif player.card_manager:
            player.card_manager.receive_into_discard(old_card)

func _card_info(cd: CardData) -> String:
    var s := cd.nice_name
    if cd is BaseWeapon:
        s += "（范围 %d）" % (cd as BaseWeapon).attack_range
    return s

func reset_property() -> void:
    card = null
    target = null
    _old_card_nice = ""
    _new_info = ""
    _failed = false


func _get_action_info() -> String:
    if card == null:
        return ""
    if _failed:
        return "[color=#f06060]装备失败：[%s] 保留在手牌中[/color]" % card.nice_name
    if _old_card_nice.is_empty():
        return "%s 装备了 [%s]" % [player.player_name, _new_info]
    return "%s 装备了 [%s]，替换了 [%s]" % [player.player_name, _new_info, _old_card_nice]
