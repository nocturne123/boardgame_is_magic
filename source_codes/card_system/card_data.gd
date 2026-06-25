class_name CardData
extends Resource

## 纯数据卡牌基类，取代插件的 CardUIData。
## 所有卡牌脚本（Baseplay 及其子类）继承此类。

@export var nice_name: String = ""
@export var type: String = ""
@export var identity: String = ""
@export var description: String = ""
@export var equipment_slot: String = ""
@export var goes_to_collection_after_use: bool = false
@export_file("*.png") var texture_path: String = ""

## 装备牌附带的技能 id 列表。装备时挂接到角色，卸下时移除。
var skill_ids: Array[String] = []

## 是否需要攻击距离校验（卡牌 JSON 中声明）。
@export var needs_range_check: bool = false
## 攻击距离（仅 needs_range_check=true 时有效。Attack 类型由武器+meta 动态计算）。
@export var effective_range: int = 1

func resolve(_source: Player, _target: Player) -> Variant:
    return null

## 执行卡牌效果。返回 true 表示已处理，返回 false 表示此类无独立执行逻辑。
func execute(_source: Player, _target: Player, _card_manager: CardManager) -> bool:
    return false

func format_description() -> String:
    return description if description else nice_name

## 装备时触发。子类重写以应用加成效果（如 +1 攻击范围、+2 护甲等）。
func on_equip(_player: Player, _slot: int) -> void:
    pass

## 被卸下/弃置时触发。子类重写以移除加成效果。
func on_unequip(_player: Player, _slot: int) -> void:
    pass
