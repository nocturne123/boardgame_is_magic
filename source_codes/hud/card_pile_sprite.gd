class_name CardPileSprite
extends PanelContainer

## 抽牌堆 / 弃牌堆可视化组件。显示堆名和数量，点击可交互。

signal pile_clicked(pile_sprite: CardPileSprite)

var pile_name: String = ""
var card_count: int = 0

var name_label: Label
var count_label: Label


func _ready() -> void:
    custom_minimum_size = Vector2(110, 70)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_ui()
    gui_input.connect(_on_gui_input)


func _build_ui() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.07, 0.06)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.3, 0.28, 0.25)
    style.set_corner_radius_all(6)
    style.content_margin_left = 6
    style.content_margin_right = 6
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    add_theme_stylebox_override("panel", style)

    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 4)
    add_child(vbox)

    name_label = Label.new()
    name_label.name = "NameLabel"
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 12)
    name_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
    vbox.add_child(name_label)

    count_label = Label.new()
    count_label.name = "CountLabel"
    count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count_label.add_theme_font_size_override("font_size", 20)
    count_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
    vbox.add_child(count_label)


func setup(p_name: String, p_count: int) -> void:
    pile_name = p_name
    card_count = p_count
    if name_label:
        name_label.text = pile_name
    if count_label:
        count_label.text = str(card_count)


func update_count(p_count: int) -> void:
    card_count = p_count
    if count_label:
        count_label.text = str(card_count)


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            pile_clicked.emit(self)
