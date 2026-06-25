class_name PartyCannonRecovery extends BaseAction

## 派对大炮恢复入口：准备掷骰参数，临时将 PartyCannonResult 挂到骰子链末端，
## 再让链条走到骰子链。PartyCannonResult 执行完后恢复骰子链原状。
## 由 UseBaseplay 在攻击牌结算后路由到此节点。

var _saved_dice_end: BaseAction = null
var _saved_dice_next: BaseAction = null

func take_action() -> void:
    pass

func inform_next_action() -> void:
    var tree: ActionTree = get_parent() as ActionTree
    if tree == null:
        return

    # 保存骰子链末端，将来恢复
    _saved_dice_end = tree.roll_dice_entry
    while _saved_dice_end.next_action != null:
        _saved_dice_end = _saved_dice_end.next_action
    _saved_dice_next = _saved_dice_end.next_action

    # 临时把 PartyCannonResult 挂到骰子链末端
    var result_node: PartyCannonResult = tree.get_node_or_null("PartyCannonResult") as PartyCannonResult
    if result_node:
        _saved_dice_end.next_action = result_node
        result_node.set_restore_target(_saved_dice_end, _saved_dice_next)

    # 启动骰子链
    tree.roll_dice_entry.purpose = "party_cannon"
    next_action = tree.roll_dice_entry

func reset_property() -> void:
    _saved_dice_end = null
    _saved_dice_next = null


func _get_action_info() -> String:
    return ""
