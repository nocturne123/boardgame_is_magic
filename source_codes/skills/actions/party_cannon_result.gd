class_name PartyCannonResult extends BaseAction

## 派对大炮恢复判定：读 dice_result，≥3 则路由到恢复链。
## 执行完后恢复骰子链原末端，避免污染后续掷骰。

var _dice: int = 0
var _success: bool = false
var _restore_end: BaseAction = null
var _restore_next: BaseAction = null

func set_restore_target(end_node: BaseAction, next_node: BaseAction) -> void:
    _restore_end = end_node
    _restore_next = next_node

func take_action() -> void:
    var tree: ActionTree = get_parent() as ActionTree
    if tree == null:
        return
    _dice = tree.roll_dice_entry.dice_result
    if _dice >= 3:
        _success = true

func inform_next_action() -> void:
    # 恢复骰子链原末端
    if _restore_end:
        _restore_end.next_action = _restore_next

    if not _success:
        return
    var tree: ActionTree = get_parent() as ActionTree
    if tree == null:
        return
    tree.heal_entry.heal_amount = 1
    next_action = tree.heal_entry

func reset_property() -> void:
    _dice = 0
    _success = false
    _restore_end = null
    _restore_next = null


func _get_action_info() -> String:
    if _success:
        return "%s 派对时间判定成功，恢复 1 点体力" % player.player_name
    return "%s 派对时间判定失败" % player.player_name
