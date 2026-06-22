class_name EquipmentBar
extends PanelContainer

## 装备栏 + 收藏品栏 HUD 组件。
## 3列2行网格布局：上排武器/防具/元素，下排收藏品×3。
## 技能栏已移至外部（手牌区上方），通过 set_skill_tray() 注入引用。
##
## 职责：
## - 监听 player.equipment_changed 刷新显示（防抖）
## - 管理 DiscardZone（拖拽时滑入/滑出）
## - 响应装备槽拖拽，分发 ActionTree 调用
## - 处理 UnequipAction.unequip_blocked 信号
## - 管理技能槽（外部 SkillTray 节点）

const _DiscardZone = preload("res://source_codes/hud/discard_zone.gd")
const _SkillSlot = preload("res://source_codes/hud/skill_slot.gd")

@onready var _weapon_slot: EquipmentSlot   = $EquipGrid/WeaponSlot
@onready var _armor_slot: EquipmentSlot    = $EquipGrid/ArmorSlot
@onready var _element_slot: EquipmentSlot  = $EquipGrid/ElementSlot
@onready var _collection_slot0: EquipmentSlot = $EquipGrid/CollectionSlot0
@onready var _collection_slot1: EquipmentSlot = $EquipGrid/CollectionSlot1
@onready var _collection_slot2: EquipmentSlot = $EquipGrid/CollectionSlot2

var _player: Player = null
var _hud: Node = null                 ## HudBattle 引用
var _discard_zone: DiscardZone = null
var _refresh_pending: bool = false
var _skill_slots: Array[SkillSlot] = []
var _skill_tray: HBoxContainer = null  ## 外部注入，在手牌区上方


# ---- 绑定/解绑 Player ----

func setup(p: Player, hud: Node) -> void:
    if _player == p:
        return
    if _player:
        _player.equipment_changed.disconnect(_on_equipment_changed)
        _player.skill_added.disconnect(_on_skill_added)
        _player.skill_removed.disconnect(_on_skill_removed)
    _player = p
    _hud = hud
    if _player:
        _player.equipment_changed.connect(_on_equipment_changed)
        _player.skill_added.connect(_on_skill_added)
        _player.skill_removed.connect(_on_skill_removed)
        _connect_slot_signals()
    _ensure_discard_zone()
    _refresh_all()
    _refresh_skills()


## 注入外部技能栏容器（由 HudBattle 调用）
func set_skill_tray(tray: HBoxContainer) -> void:
    _skill_tray = tray


func _connect_slot_signals() -> void:
    var slots: Array[EquipmentSlot] = [
        _weapon_slot, _armor_slot, _element_slot,
        _collection_slot0, _collection_slot1, _collection_slot2,
    ]
    for slot in slots:
        # 先断开旧连接（防止切换玩家后重复）
        if slot.card_dropped.is_connected(_on_slot_drop):
            slot.card_dropped.disconnect(_on_slot_drop)
        if slot.drag_started.is_connected(_on_drag_started):
            slot.drag_started.disconnect(_on_drag_started)
        if slot.drag_ended.is_connected(_on_drag_ended):
            slot.drag_ended.disconnect(_on_drag_ended)
        if slot.card_hovered.is_connected(_on_slot_hovered):
            slot.card_hovered.disconnect(_on_slot_hovered)
        # 重新连接
        slot.card_dropped.connect(_on_slot_drop)
        slot.drag_started.connect(_on_drag_started)
        slot.drag_ended.connect(_on_drag_ended)
        slot.card_hovered.connect(_on_slot_hovered)


# ---- DiscardZone 生命周期 ----

func _ensure_discard_zone() -> void:
    if _discard_zone != null and is_instance_valid(_discard_zone):
        return
    _discard_zone = _DiscardZone.new()
    _discard_zone.name = "DiscardZone"
    _discard_zone.card_discard_requested.connect(_on_discard_requested)
    var hud_layer := _find_hud_layer()
    if hud_layer:
        hud_layer.add_child(_discard_zone)


func _find_hud_layer() -> CanvasLayer:
    if _hud and _hud.get("card_layer") != null:
        return _hud.card_layer as CanvasLayer
    var node := get_parent()
    while node:
        if node is CanvasLayer:
            return node as CanvasLayer
        node = node.get_parent()
    return null


func _on_drag_started(_slot: EquipmentSlot) -> void:
    if _discard_zone and is_instance_valid(_discard_zone):
        _discard_zone.slide_in()


func _on_drag_ended(_slot: EquipmentSlot) -> void:
    if _discard_zone and is_instance_valid(_discard_zone):
        _discard_zone.slide_out()


# ---- 悬停 → 显示卡牌详情 ----

func _on_slot_hovered(card: CardData) -> void:
    if _hud and _hud.has_method("_show_card_detail"):
        _hud._show_card_detail(card)


# ---- 弃置处理 (DiscardZone → UnequipAction) ----

func _on_discard_requested(src_slot: EquipmentSlot) -> void:
    if _player == null:
        return
    var action := _get_or_create_action("UnequipAction")
    if action == null:
        return
    action.slot = src_slot.slot_type
    if action.has_signal("unequip_blocked") and not action.unequip_blocked.is_connected(_on_unequip_blocked):
        action.unequip_blocked.connect(_on_unequip_blocked, CONNECT_ONE_SHOT)
    _player.get_node("ActionTree").chain_of_actions(action)
    if _discard_zone and is_instance_valid(_discard_zone):
        _discard_zone.slide_out()


func _on_unequip_blocked(reason: String) -> void:
    if _discard_zone and is_instance_valid(_discard_zone):
        _discard_zone.shake()
    print("[装备栏] " + reason)


# ---- 刷新（防抖 — swap 时的 4 次 signal 合并为 1 次）----

func _on_equipment_changed(_slot: int) -> void:
    if not _refresh_pending:
        _refresh_pending = true
        call_deferred("_deferred_refresh")


func _deferred_refresh() -> void:
    _refresh_pending = false
    _refresh_all()


func _refresh_all() -> void:
    if _player == null:
        return
    var weapon_arr: Array = _player.get_equipment_in_slot(Player.EquipmentSlotType.Weapon)
    _weapon_slot.set_card(weapon_arr[0] if weapon_arr.size() > 0 else null)

    var armor_arr: Array = _player.get_equipment_in_slot(Player.EquipmentSlotType.Armor)
    _armor_slot.set_card(armor_arr[0] if armor_arr.size() > 0 else null)

    var elem_arr: Array = _player.get_equipment_in_slot(Player.EquipmentSlotType.Element)
    _element_slot.set_card(elem_arr[0] if elem_arr.size() > 0 else null)

    _refresh_collection()


func _refresh_collection() -> void:
    var coll: Array = _player.get_equipment_in_slot(Player.EquipmentSlotType.Collection)
    var c_slots := [_collection_slot0, _collection_slot1, _collection_slot2]
    for i in range(3):
        c_slots[i].set_card(coll[i] if i < coll.size() else null)


# ---- 拖拽分发 ----

func _on_slot_drop(src_slot: EquipmentSlot, dst_slot: EquipmentSlot, card: CardData) -> void:
    if _player == null:
        return
    var src_is_collection: bool = src_slot.is_collection_slot
    var dst_is_collection: bool = dst_slot.is_collection_slot
    var card_identity: String = card.identity if card else ""

    if not src_is_collection and dst_is_collection:
        _send_action("MoveEquipmentToCollection", {"slot": src_slot.slot_type, "card_identity": card_identity})
        return

    if src_is_collection and not dst_is_collection:
        _send_action("EquipFromCollection", {"slot": dst_slot.slot_type, "card_identity": card_identity})
        return

    if not src_is_collection and not dst_is_collection:
        _swap_equipment(src_slot, dst_slot)


# ---- ActionTree 通信 ----

func _send_action(action_name: String, params: Dictionary) -> void:
    var action := _get_or_create_action(action_name)
    if action == null:
        return
    for key in params:
        action.set(key, params[key])
    _player.get_node("ActionTree").chain_of_actions(action)


func _get_or_create_action(action_name: String) -> Node:
    var atree: ActionTree = _player.get_node_or_null("ActionTree")
    if atree == null:
        return null
    var node := atree.get_node_or_null(action_name)
    if node == null:
        var script_path := "res://source_codes/players/actions/" + action_name + ".gd"
        if not FileAccess.file_exists(script_path):
            return null
        var scr := load(script_path)
        if scr == null:
            return null
        node = scr.new()
        node.name = action_name
        atree.add_child(node)
    return node


# ---- 技能栏管理（外部 SkillTray）----

func _on_skill_added(_skill: SkillData) -> void:
    _refresh_skills()


func _on_skill_removed(_skill: SkillData) -> void:
    _refresh_skills()


func _refresh_skills() -> void:
    # 清理旧 SkillSlot
    for slot in _skill_slots:
        if is_instance_valid(slot):
            slot.queue_free()
    _skill_slots.clear()

    if _player == null or _skill_tray == null:
        return

    # 为每个技能创建 SkillSlot
    for skill in _player.get_skills():
        var slot: SkillSlot = _SkillSlot.new()
        _skill_tray.add_child(slot)
        slot.set_skill(skill)
        slot.skill_hovered.connect(_on_skill_hovered)
        slot.skill_unhovered.connect(_on_skill_unhovered)
        slot.skill_clicked.connect(_on_skill_clicked)
        _skill_slots.append(slot)


func _on_skill_hovered(skill: SkillData) -> void:
    if _hud and _hud.has_method("_show_skill_detail"):
        _hud._show_skill_detail(skill)


func _on_skill_unhovered() -> void:
    if _hud and _hud.has_method("_clear_detail"):
        _hud._clear_detail()


func _on_skill_clicked(skill: SkillData) -> void:
    # 主动技能点击：转发给 HudBattle 处理
    if _hud and _hud.has_method("_on_skill_activated"):
        _hud._on_skill_activated(skill)


func _swap_equipment(a: EquipmentSlot, b: EquipmentSlot) -> void:
    # 同类型交换仅在存在多个同类型槽位时可达（当前每种槽只有 1 个）
    # 保留此方法作为占位，实际交换应通过 ActionTree
    pass
