class_name RangeCheck extends BaseAction

## 可复用的距离校验节点。UseCard / UseSkill 按需注入参数后路由到此节点。
## 距离不足时设 next_action = null 阻断链，不消耗卡牌/次数。

var source: Player = null
var target: Player = null
var max_range: int = 1
var _dist: int = 0
var _passed: bool = true

func take_action() -> void:
    if source == null or target == null:
        return
    _dist = _cube_distance(source.cube_position, target.cube_position)
    if _dist > max_range:
        _passed = false
        next_action = null

static func _cube_distance(a: Vector3i, b: Vector3i) -> int:
    return max(abs(a.x - b.x), abs(a.y - b.y), abs(a.z - b.z))

func _get_action_info() -> String:
    if source == null or target == null:
        return ""
    var tname := target.player_name if target else "?"
    if not _passed:
        return "[color=#f06060]%s → %s  距离 %d，超出攻击范围 %d！[/color]" % [source.player_name, tname, _dist, max_range]
    return "%s → %s  距离 %d / 范围 %d" % [source.player_name, tname, _dist, max_range]

func reset_property() -> void:
    source = null
    target = null
    max_range = 1
    _dist = 0
    _passed = true
