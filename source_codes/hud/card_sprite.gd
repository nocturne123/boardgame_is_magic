class_name CardSprite
extends PanelContainer

## 单张卡牌的可视化组件。
## 贴图填满全牌 → 上半透明留白给图面 → 下半透明黑底文字区。

signal card_clicked(card_sprite: CardSprite)
signal card_hovered(card_sprite: CardSprite)

var card_data: CardData = null
var is_selected: bool = false

var name_label: Label
var type_label: Label
var texture_rect: TextureRect
var _ui_built: bool = false


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(100, 140)
    _build_ui()
    _apply_card_data()
    pivot_offset = Vector2(custom_minimum_size.x / 2.0, custom_minimum_size.y)
    gui_input.connect(_on_gui_input)
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)


func _build_ui() -> void:
    theme_type_variation = ""

    var outer_style := StyleBoxFlat.new()
    outer_style.bg_color = Color(0.12, 0.1, 0.08)
    outer_style.border_width_left = 2
    outer_style.border_width_right = 2
    outer_style.border_width_top = 2
    outer_style.border_width_bottom = 2
    outer_style.border_color = Color(0.4, 0.35, 0.3)
    outer_style.set_corner_radius_all(8)
    outer_style.shadow_size = 4
    outer_style.shadow_color = Color(0, 0, 0, 0.35)
    outer_style.shadow_offset = Vector2(0, 2)
    outer_style.content_margin_left = 0
    outer_style.content_margin_right = 0
    outer_style.content_margin_top = 0
    outer_style.content_margin_bottom = 0
    add_theme_stylebox_override("panel", outer_style)

    var overlay := Control.new()
    overlay.name = "Overlay"
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)

    # 底色
    var bg := ColorRect.new()
    bg.color = Color(0.15, 0.13, 0.11)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(bg)

    # 贴图 — 填满牌面
    texture_rect = TextureRect.new()
    texture_rect.name = "TextureRect"
    texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    overlay.add_child(texture_rect)

    # VBox：透明留白 + 半透明黑底文字
    var vbox := VBoxContainer.new()
    vbox.name = "CardVBox"
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(vbox)

    # 透明留白 — 给贴图展示空间
    var spacer := Control.new()
    spacer.name = "Spacer"
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(spacer)

    # 半透明黑底文字区
    var text_panel := PanelContainer.new()
    text_panel.name = "TextPanel"
    text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0, 0, 0, 0.55)
    panel_style.content_margin_left = 4
    panel_style.content_margin_right = 4
    panel_style.content_margin_top = 3
    panel_style.content_margin_bottom = 4
    text_panel.add_theme_stylebox_override("panel", panel_style)
    vbox.add_child(text_panel)

    var text_vbox := VBoxContainer.new()
    text_vbox.add_theme_constant_override("separation", 1)
    text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    text_panel.add_child(text_vbox)

    name_label = Label.new()
    name_label.name = "NameLabel"
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 12)
    name_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
    text_vbox.add_child(name_label)

    type_label = Label.new()
    type_label.name = "TypeLabel"
    type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    type_label.add_theme_font_size_override("font_size", 10)
    type_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
    text_vbox.add_child(type_label)

    _ui_built = true


func setup(p_card_data: CardData) -> void:
    card_data = p_card_data
    if _ui_built:
        _apply_card_data()


func _apply_card_data() -> void:
    if card_data == null:
        return
    if name_label:
        name_label.text = card_data.nice_name
    if type_label:
        type_label.text = _type_display_name(card_data.type)
    if texture_rect:
        if card_data.texture_path and not card_data.texture_path.is_empty():
            var tex := load(card_data.texture_path) as Texture2D
            if tex:
                texture_rect.texture = tex


func _type_display_name(t: String) -> String:
    match t:
        "Attack":   return "攻击"
        "Steal":    return "偷牌"
        "Event":    return "事件"
        "Effect":   return "效果"
        "Recovery": return "恢复"
        "Weapon":   return "武器"
        "Armor":    return "防具"
        "Element":  return "元素"
        _:          return t


func set_selected(selected: bool) -> void:
    is_selected = selected
    if selected:
        _apply_border_style(Color(1.0, 0.84, 0.0), 3)
    else:
        _apply_border_style(Color(0.4, 0.35, 0.3), 2)


func _apply_border_style(border_color: Color, border_width: int) -> void:
    var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
    if style:
        style.border_color = border_color
        style.border_width_left = border_width
        style.border_width_right = border_width
        style.border_width_top = border_width
        style.border_width_bottom = border_width
        add_theme_stylebox_override("panel", style)


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            card_clicked.emit(self)


func _on_mouse_entered() -> void:
    card_hovered.emit(self)
    if not is_selected:
        _apply_border_style(Color(0.55, 0.5, 0.45), 2)


func _on_mouse_exited() -> void:
    if not is_selected:
        _apply_border_style(Color(0.4, 0.35, 0.3), 2)
