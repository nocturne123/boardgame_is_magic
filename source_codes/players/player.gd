class_name Player extends Sprite2D

enum Species {EarthPony, Unicorn, Pegasi, Alicon, others}
enum PlayerState {Wait, Draw, Play, Discard}
enum LivingState {Alive,Fainted,Dead}
## 装备栏类型。收集品的装备逻辑稍后单独实现。
enum EquipmentSlotType { Weapon, Armor, Element, Collection }

@export_group("基础属性")
@export var player_name:String
#生命值、最大生命值、初始生命值
@export var health:int
@export var max_health:int
@export var base_health:int
@export var armor: int = 0:
    set(v):
        armor = clampi(v, 0, 4)
@export var speed:int = 1
@export var attack_range: int = 1
@export var species:Species
@export var living_state:LivingState = LivingState.Alive
@export var turn_stage = PlayerState.Wait
@export var map_position:Vector2i
## 插件原生 cube 坐标（Vector3i），由战斗场景在设置 map_position 后同步。
## 所有六边形数学运算（距离、范围、寻路）应使用此坐标。
@export var cube_position:Vector3i = Vector3i.ZERO
#玩家的回合计数和轮次计数
@export var turn_count:int = 0
@export var round_count:int = 0

@export_group("额外属性")
@export var physical_ability:int
@export var magic_ability:int
@export    var mental_ability:int
@export var physical_defence:int
@export var magic_defence:int
@export    var mental_defence:int
#可以被卡牌指定，比如攻击牌、偷牌
@export var is_selectable:bool = true
@export var immune_from_attack:bool = false
@export var immune_from_steal:bool = false
#角色在回合开始时的抽牌
@export var draw_stage_card_number:int = 2
#角色初始手牌数量
@export var start_game_draw:int = 4
#角色最大手牌数量
@export var max_hand_sequence_num = 6
#玩家的移动次数和攻击次数，在回合开始时用这个属性进行初始化
@export var move_chance:int = 1
@export var attack_chance:int = 1
#玩家在回合中的移动和攻击次数，回合开始时从上面的属性初始化得到
@export var move_chance_in_turn:int = 0
@export var attack_chance_in_turn:int = 0
#玩家在上一轮的生命值，记录给沙漏使用，在回合结束时记录
@export var health_last_turn:int = max_health

## 宝石 buff：下次心理攻击额外伤害和护甲穿透（Gem 卡牌设置，BaseAttack.resolve 消费后清零）
var next_mental_bonus: int = 0
var next_mental_ignore_armor: bool = false

## 是否已集齐 3 个收藏品（永久标记，不因弃置收藏品而重置）。
@export var collection_completed: bool = false

## 已获得收藏品的 identity 集合（去重用，防止槽位间移动重复加血）。
var _owned_collectible_ids: Array[String] = []

@export_group("hand_pile_setting")
@export var hand_pile_position = Vector2(640, 480)
@export var hand_enabled := true
@export var hand_face_up := true
@export var max_hand_size := 10 # if any more cards are added to the hand, they are immediately discarded
@export var max_hand_spread := 400
@export var card_ui_hover_distance := 60
@export var drag_when_clicked := true

## This works best as a 2-point linear rise from -X to +X
@export var hand_rotation_curve : Curve
## This works best as a 3-point ease in/out from 0 to X to 0
@export var hand_vertical_curve : Curve

## 装备栏：按槽位类型分组，每格为卡牌 identity 字符串数组。
## Collection 栏位只存"已收集、当前未在功能栏"的收藏品 identity。
var equipment: Dictionary = {}

## 本角色专属收藏品的 identity 列表（如灰琪：派对大炮、衣服、宝石）。仅这些牌可进入收藏品栏位。
@export var collection_item_ids: Array[String] = []

## 当该玩家为木桩时，表示其手牌（卡牌 nice_name 列表），用于偷牌测试。非木桩玩家可留空。
var hand_card_nice_names: Array[String] = []

## 指向 CardManager 的引用，由战斗场景注入。ActionTree 动作通过它访问抽牌堆和弃牌堆。
var card_manager: CardManager = null

## 当前手牌（Array[CardData]）。
var hand: Array[CardData] = []

signal card_added_to_hand(card_data: CardData)
signal card_removed_from_hand(card_data: CardData)
signal hand_updated()
## 装备栏变更时发射。参数为发生变更的栏位类型。
signal equipment_changed(slot: EquipmentSlotType)

## 集齐 3 个收藏品时发射（仅触发一次）。
signal collection_finished()

## 技能系统
var skills: Array[SkillData] = []
signal skill_added(skill: SkillData)
signal skill_removed(skill: SkillData)

func _init() -> void:
    equipment[EquipmentSlotType.Weapon] = []
    equipment[EquipmentSlotType.Armor] = []
    equipment[EquipmentSlotType.Element] = []
    equipment[EquipmentSlotType.Collection] = []
## 该 identity 是否为本角色可收集的收藏品。
func is_collection_item(card_identity: String) -> bool:
    if card_identity.is_empty():
        return false
    for id in collection_item_ids:
        if id == card_identity:
            return true
    return false

## 指定功能栏（Weapon/Armor/Element）是否被收藏品占用。
## 即栏位中是否存在 is_collection_item 为 true 的卡牌。
func is_slot_occupied_by_collection(slot: EquipmentSlotType) -> bool:
    for cd in get_equipment_in_slot(slot):
        if cd == null:
            continue
        if is_collection_item(cd.identity):
            return true
    return false

## 返回该牌当前所在槽位，若不在任何槽位则返回 -1。
func get_slot_of_card(card: CardData) -> int:
    if card == null:
        return -1
    for slot in equipment.keys():
        var arr: Array = equipment[slot] as Array
        if arr.has(card):
            return slot
    return -1

## 将牌移入收藏品栏位：先从武器/防具/元素栏移除（若在），再加入 Collection。仅允许本角色收藏品。on_unequip 由调用方负责。
func move_to_collection_slot(card: CardData) -> bool:
    if card == null or not is_collection_item(card.identity):
        return false
    var slot := get_slot_of_card(card)
    if slot >= 0:
        var arr: Array = get_equipment_in_slot(slot as EquipmentSlotType)
        var idx := arr.find(card)
        if idx >= 0:
            arr.remove_at(idx)
            equipment[slot as EquipmentSlotType] = arr
            equipment_changed.emit(slot as EquipmentSlotType)
    var coll: Array = get_equipment_in_slot(EquipmentSlotType.Collection)
    if not coll.has(card):
        coll.append(card)
        equipment[EquipmentSlotType.Collection] = coll
    equipment_changed.emit(EquipmentSlotType.Collection)
    return true

## 将牌从收藏品栏位移到指定功能栏。若目标栏已有牌，不自动弃置，由调用方先处理。on_equip 由调用方负责。
func move_from_collection_to_slot(card: CardData, slot: EquipmentSlotType) -> bool:
    if card == null or slot == EquipmentSlotType.Collection:
        return false
    var coll: Array = get_equipment_in_slot(EquipmentSlotType.Collection)
    var idx := coll.find(card)
    if idx < 0:
        return false
    coll.remove_at(idx)
    equipment[EquipmentSlotType.Collection] = coll
    equipment_changed.emit(EquipmentSlotType.Collection)
    var arr: Array = get_equipment_in_slot(slot)
    arr.append(card)
    equipment[slot] = arr
    equipment_changed.emit(slot)
    return true

func move_to_position(target: Vector2i) -> void:
    map_position = target

func get_equipment_in_slot(slot: EquipmentSlotType) -> Array:
    if not equipment.has(slot):
        return []
    return equipment[slot] as Array

func has_equipment_in_slot(slot: EquipmentSlotType) -> bool:
    return get_equipment_in_slot(slot).size() > 0

## 向指定栏位添加卡牌。仅做容器操作 + 发射信号。on_equip 由调用方（Action）负责。
func _add_to_slot(slot: EquipmentSlotType, card: CardData) -> void:
    var arr: Array = get_equipment_in_slot(slot)
    arr.append(card)
    equipment[slot] = arr
    equipment_changed.emit(slot)
    # 集齐 3 个收藏品时标记完成并通知（仅触发一次）
    if card and is_collection_item(card.identity) and not _owned_collectible_ids.has(card.identity):
        _owned_collectible_ids.append(card.identity)
        if _owned_collectible_ids.size() >= 3 and not collection_completed:
            collection_completed = true
            collection_finished.emit()

## 从指定栏位移除第 index 张牌。仅做容器操作 + 发射信号。on_unequip 由调用方（Action）负责。
func _remove_from_slot(slot: EquipmentSlotType, index: int) -> CardData:
    var arr: Array = get_equipment_in_slot(slot)
    if index >= 0 and index < arr.size():
        var card: CardData = arr[index] as CardData
        arr.remove_at(index)
        equipment[slot] = arr
        equipment_changed.emit(slot)
        return card
    return null

func has_weapon() -> bool:
    return has_equipment_in_slot(EquipmentSlotType.Weapon)

func has_armor() -> bool:
    return has_equipment_in_slot(EquipmentSlotType.Armor)

func has_element() -> bool:
    return has_equipment_in_slot(EquipmentSlotType.Element)

func has_collection() -> bool:
    return has_equipment_in_slot(EquipmentSlotType.Collection)

## 获取玩家当前持有的所有收藏品（遍历所有槽位）。
## 返回 Array[CardData]，可能为空。
func get_all_collection_items() -> Array:
    var result: Array = []
    for slot in equipment.keys():
        for cd in get_equipment_in_slot(slot):
            if cd is CardData and is_collection_item(cd.identity):
                result.append(cd)
    return result

# ============================================================
# 手牌管理（数据类管理自己的容器）
# ============================================================

func add_card_to_hand(card_data: CardData) -> void:
    if card_data == null:
        return
    hand.push_back(card_data)
    card_added_to_hand.emit(card_data)
    hand_updated.emit()

func remove_card_from_hand(card_data: CardData) -> void:
    if card_data == null:
        return
    hand.erase(card_data)
    card_removed_from_hand.emit(card_data)
    hand_updated.emit()

func get_hand() -> Array[CardData]:
    return hand.duplicate()

func get_hand_size() -> int:
    return hand.size()

func is_hand_at_max_capacity() -> bool:
    # 规则 5.3：手牌上限 6 张（max_hand_sequence_num），弃到 6 张后回合结束
    return hand.size() >= max_hand_sequence_num


# ============================================================
# 技能管理
# ============================================================

## 挂接技能：技能自行通过 on_attach 修改 ActionTree 链条。
func add_skill(skill: SkillData) -> void:
    if skill == null or skills.has(skill):
        return
    skills.append(skill)
    skill.on_attach(self)
    skill_added.emit(skill)

## 卸下技能：技能自行通过 on_detach 恢复默认链条。
func remove_skill(skill: SkillData) -> void:
    if skill == null or not skills.has(skill):
        return
    skill.on_detach(self)
    skills.erase(skill)
    skill_removed.emit(skill)

func get_skills() -> Array[SkillData]:
    return skills.duplicate()

func has_skill(skill_id: String) -> bool:
    for s in skills:
        if s.id == skill_id:
            return true
    return false
