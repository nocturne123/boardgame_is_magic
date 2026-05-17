class_name EquipmentSlot
extends PanelContainer

## 装备/收藏品槽位。贴图填满全槽，名称/属性文字叠在贴图上。

@export var slot_type: int = Player.EquipmentSlotType.Weapon
@export var is_collection_slot: bool = false

signal card_dropped(from_slot: EquipmentSlot, to_slot: EquipmentSlot, card: CardData)
signal drag_started(slot: EquipmentSlot)
signal drag_ended(slot: EquipmentSlot)
signal card_hovered(card: CardData)

var _card: CardData = null
var _is_dragging: bool = false

var _texture_rect: TextureRect
var _name_label: Label
var _stat_label: Label
var _star_label: Label


func _ready() -> void:
    custom_minimum_size = Vector2(64, 90)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _setup_style()
    _build_children()
    _refresh_display()
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func _setup_style() -> void:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.1, 0.09, 0.08, 0.92)
    s.border_width_left = 2
    s.border_width_right = 2
    s.border_width_top = 2
    s.border_width_bottom = 2
    s.border_color = Color(0.3, 0.27, 0.22)
    s.set_corner_radius_all(6)
    s.content_margin_left = 0
    s.content_margin_right = 0
    s.content_margin_top = 0
    s.content_margin_bottom = 0
    add_theme_stylebox_override("panel", s)

func _build_children() -> void:
    var overlay := Control.new()
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)

    # 底色
    var bg := ColorRect.new()
    bg.color = Color(0.15, 0.13, 0.11)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(bg)

    # 贴图 — 填满全槽
    _texture_rect = TextureRect.new()
    _texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    overlay.add_child(_texture_rect)

    # ★ 收藏品角标
    _star_label = Label.new()
    _star_label.text = "★"
    _star_label.add_theme_font_size_override("font_size", 14)
    _star_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
    _star_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    _star_label.add_theme_constant_override("shadow_offset_x", 1)
    _star_label.add_theme_constant_override("shadow_offset_y", 1)
    _star_label.visible = false
    _star_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 4)
    overlay.add_child(_star_label)

    # 名称 — 底部居中，带阴影
    _name_label = Label.new()
    _name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _name_label.add_theme_font_size_override("font_size", 11)
    _name_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
    _name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    _name_label.add_theme_constant_override("shadow_offset_x", 1)
    _name_label.add_theme_constant_override("shadow_offset_y", 2)
    _name_label.clip_text = true

    # 属性行 — 名称下方
    _stat_label = Label.new()
    _stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _stat_label.add_theme_font_size_override("font_size", 10)
    _stat_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
    _stat_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    _stat_label.add_theme_constant_override("shadow_offset_x", 1)
    _stat_label.add_theme_constant_override("shadow_offset_y", 2)
    _stat_label.clip_text = true

    # 底部文字容器
    var bottom_vbox := VBoxContainer.new()
    bottom_vbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom_vbox.add_theme_constant_override("separation", 1)
    bottom_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_vbox.add_child(_name_label)
    bottom_vbox.add_child(_stat_label)
    overlay.add_child(bottom_vbox)


# ---- 公共 API ----

func set_card(card: CardData) -> void:
    _card = card
    _refresh_display()

func get_card() -> CardData:
    return _card

func clear() -> void:
    _card = null
    _refresh_display()


# ---- 显示刷新 ----

func _refresh_display() -> void:
    _update_border()
    if _card:
        _name_label.text = _card.nice_name
        _name_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
        _stat_label.text = _card_stat_text()
        _star_label.visible = _card.goes_to_collection_after_use

        if _card.texture_path and not _card.texture_path.is_empty():
            var tex := load(_card.texture_path) as Texture2D
            if tex:
                _texture_rect.texture = tex
            else:
                _texture_rect.texture = null
        else:
            _texture_rect.texture = null
    else:
        _name_label.text = _placeholder_text()
        _name_label.add_theme_color_override("font_color", Color(0.35, 0.33, 0.28))
        _stat_label.text = ""
        _star_label.visible = false
        _texture_rect.texture = null


func _placeholder_text() -> String:
    if is_collection_slot:
        return "(空)"
    match slot_type:
        Player.EquipmentSlotType.Weapon:  return "武器"
        Player.EquipmentSlotType.Armor:   return "防具"
        Player.EquipmentSlotType.Element: return "元素"
    return "—"

func _card_stat_text() -> String:
    if _card == null:
        return ""
    match _card.type:
        "Weapon":
            if _card.get("attack_range") != null:
                return "范围: %d" % int(_card.get("attack_range"))
            return ""
        "Armor":
            if _card.get("physical_defence_bonus") != null and _card.get("magic_defence_bonus") != null:
                return "+%d物防 +%d法防" % [int(_card.get("physical_defence_bonus")), int(_card.get("magic_defence_bonus"))]
            return ""
    return ""


func _update_border() -> void:
    var color: Color
    var width: int
    if _card:
        var is_collection := _card.goes_to_collection_after_use
        if is_collection:
            color = Color(1.0, 0.84, 0.0)
            width = 3
        else:
            match _card.type:
                "Weapon":  color = Color(0.7, 0.5, 0.3)
                "Armor":   color = Color(0.35, 0.5, 0.7)
                "Element": color = Color(0.55, 0.35, 0.7)
                _:         color = Color(0.3, 0.27, 0.22)
            width = 2
    else:
        color = Color(0.25, 0.22, 0.2)
        width = 1

    var s := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
    if s:
        s.border_color = color
        s.border_width_left = width
        s.border_width_right = width
        s.border_width_top = width
        s.border_width_bottom = width
        add_theme_stylebox_override("panel", s)


# ---- 拖拽 ----

func _get_drag_data(_at_position: Vector2) -> Variant:
    if _card == null:
        return null
    _is_dragging = true
    drag_started.emit(self)

    var preview := PanelContainer.new()
    preview.custom_minimum_size = Vector2(60, 84)
    var pstyle := StyleBoxFlat.new()
    pstyle.bg_color = Color(0.12, 0.1, 0.08, 0.8)
    pstyle.border_width_left = 1
    pstyle.border_width_right = 1
    pstyle.border_width_top = 1
    pstyle.border_width_bottom = 1
    pstyle.border_color = Color(0.5, 0.45, 0.4)
    pstyle.set_corner_radius_all(4)
    preview.add_theme_stylebox_override("panel", pstyle)

    var pvbox := VBoxContainer.new()
    pvbox.alignment = BoxContainer.ALIGNMENT_CENTER
    pvbox.add_theme_constant_override("separation", 2)
    preview.add_child(pvbox)

    if _card.texture_path and not _card.texture_path.is_empty():
        var tex := load(_card.texture_path) as Texture2D
        if tex:
            var tr := TextureRect.new()
            tr.texture = tex
            tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            tr.custom_minimum_size = Vector2(44, 44)
            pvbox.add_child(tr)

    var plabel := Label.new()
    plabel.text = _card.nice_name
    plabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    plabel.add_theme_font_size_override("font_size", 9)
    plabel.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
    pvbox.add_child(plabel)

    set_drag_preview(preview)
    return {"source_slot": self, "card": _card, "is_collection": is_collection_slot}


func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        if _is_dragging:
            _is_dragging = false
            drag_ended.emit(self)


# ---- 拖拽接收 ----

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
    if data == null or not data is Dictionary:
        return false
    var src_slot: EquipmentSlot = data.get("source_slot", null)
    if src_slot == self:
        return false
    var cd: CardData = data.get("card", null)
    if cd == null:
        return false

    var src_is_collection: bool = data.get("is_collection", false)

    # Collection 槽：接受来自功能槽的 drop（收藏品从功能槽移回 Collection）
    if is_collection_slot:
        return not src_is_collection

    # 功能槽接受来自 Collection 槽的收藏品 drop
    # 规则：只有类型匹配的收藏品才能装入对应功能槽（Weapon→武器栏, Armor→防具栏）
    # Effect/Recovery 等类型的收藏品（如宝石）不可装入功能槽
    if src_is_collection:
        match cd.type:
            "Weapon": return slot_type == Player.EquipmentSlotType.Weapon
            "Armor":  return slot_type == Player.EquipmentSlotType.Armor
        return false

    # 同类型装备 drop（非收藏品之间）
    if cd.type == "Weapon" and slot_type == Player.EquipmentSlotType.Weapon:
        return true
    if cd.type == "Armor" and slot_type == Player.EquipmentSlotType.Armor:
        return true
    if cd.type == "Element" and slot_type == Player.EquipmentSlotType.Element:
        return true
    return false

func _drop_data(_pos: Vector2, data: Variant) -> void:
    if data == null or not data is Dictionary:
        return
    var src_slot: EquipmentSlot = data.get("source_slot", null)
    if src_slot == null:
        return
    var card: CardData = data.get("card", null)
    card_dropped.emit(src_slot, self, card)


# ---- 悬停 ----

func _on_mouse_entered() -> void:
    if _card:
        card_hovered.emit(_card)

func _on_mouse_exited() -> void:
    pass
