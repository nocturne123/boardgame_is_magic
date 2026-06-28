class_name TrixieMagicPropAction extends BaseAction

## 魔术道具执行节点（仅武器/防具路径）：
## - 卡牌在 HUD 对话框中暂存（_magic_prop_card），不立即弃置
## - 暂停等选攻击类型 → 创建虚拟攻击 → 走 UseCard 全链
## - UseBaseplay 之后挂 MagicPropDiscard 节点：攻击成功则弃牌，失败则交还

var target: Player = null
var card_to_discard: CardData = null
var chosen_damage_type: int = -1

func take_action() -> void:
    if card_to_discard == null:
        return
    waiting = true

func inform_next_action() -> void:
    if chosen_damage_type < 0 or target == null:
        return

    var tree: ActionTree = get_parent() as ActionTree

    # 创建虚拟攻击牌
    var virtual_card := BaseAttack.new()
    virtual_card.type = "Attack"
    virtual_card.identity = "__trixie_virtual__"
    var type_name: String
    match chosen_damage_type:
        Damage.DamageType.Physical:
            virtual_card.damage_type = Damage.DamageType.Physical
            type_name = "物理"
        Damage.DamageType.Magic:
            virtual_card.damage_type = Damage.DamageType.Magic
            type_name = "法术"
        Damage.DamageType.Mental:
            virtual_card.damage_type = Damage.DamageType.Mental
            type_name = "心理"
    virtual_card.nice_name = "魔术道具(%s)" % type_name

    # 找到 UseBaseplay，临时挂上 MagicPropDiscard（保存/恢复模式）
    var ubp: UseBaseplay = tree.use_card.get_node_or_null("UseBaseplay") as UseBaseplay
    if ubp:
        var gen: int = player.get_meta("magic_prop_gen", 0) + 1
        player.set_meta("magic_prop_gen", gen)

        var discard := MagicPropDiscard.new()
        discard.name = "MagicPropDiscard"
        discard.reserved_card = card_to_discard
        discard.restore_target = ubp
        discard.restore_next = ubp.next_action
        tree.add_child(discard)
        ubp.next_action = discard

    tree.use_card.card = virtual_card
    tree.use_card.target = target
    next_action = tree.use_card

func reset_property() -> void:
    target = null
    card_to_discard = null
    chosen_damage_type = -1


func _get_action_info() -> String:
    return ""
