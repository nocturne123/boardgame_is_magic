class_name HudBattle
extends Node2D

const _TilemapHUD = preload("res://source_codes/hud/tilemap_hud.gd")
const _CardArrow = preload("res://source_codes/hud/card_arrow.gd")
const _HandFan = preload("res://source_codes/hud/hand_fan.gd")

## 可交互的完整战斗场景。
## 程序化构建 UI（手牌区、抽/弃牌堆、玩家信息、卡牌详情、回合指示器）。
## 使用 CanvasLayer + 锚点容器实现自适应窗口布局。
## HUD 与逻辑通过信号沟通，箭头指向系统类似杀戮尖塔。

signal card_use_requested(card_data: CardData, source: Player, target: Player)
signal move_requested(target_cell: Vector2i)

# ---- 场景节点 ----
@onready var card_mgr: CardManager = $logic/CardManager
@onready var turn_mgr: TurnManager = $logic/TurnManager
@onready var skill_mgr: SkillManager = $logic/SkillManager
@onready var event_mgr: EventManager = $logic/EventManager
@onready var event_deck: EventDeck = $logic/EventDeck
@onready var map_layer: MapLayer = $MapLayer
@onready var map_node: TileMapLayer = $MapLayer/Layer0
@onready var player_a: Player = $MapLayer/Player1
@onready var player_b: Player = $MapLayer/Player2
@onready var card_layer: CanvasLayer = $HudLayer

# ---- HUD 节点（来自 tscn 场景）----
@onready var _hud_container: Control = $HudLayer/HudContainer
@onready var main_vbox: VBoxContainer = $HudLayer/HudContainer/Margin/MainVBox
@onready var top_bar: PanelContainer = $HudLayer/HudContainer/Margin/MainVBox/TopBar
@onready var turn_label: Label = $HudLayer/HudContainer/Margin/MainVBox/TopBar/TopHBox/TurnLabel
@onready var round_label: Label = $HudLayer/HudContainer/Margin/MainVBox/TopBar/TopHBox/RoundLabel
@onready var current_player_label: Label = $HudLayer/HudContainer/Margin/MainVBox/TopBar/TopHBox/CurrentPlayerLabel
@onready var end_turn_button: Button = $HudLayer/HudContainer/Margin/MainVBox/TopBar/TopHBox/EndTurnButton
@onready var move_mode_indicator: Label = $HudLayer/HudContainer/Margin/MainVBox/TopBar/TopHBox/MoveModeIndicator
@onready var left_panel: PlayerInfoPanel = $HudLayer/HudContainer/Margin/MainVBox/MiddleHBox/LeftPanel
@onready var card_detail_panel: PanelContainer = $HudLayer/HudContainer/Margin/MainVBox/MiddleHBox/RightVBox/CardDetailPanel
@onready var card_detail_label: RichTextLabel = $HudLayer/HudContainer/Margin/MainVBox/MiddleHBox/RightVBox/CardDetailPanel/CardDetailVBox/CardDetailLabel
@onready var log_panel: PanelContainer = $HudLayer/HudContainer/Margin/MainVBox/MiddleHBox/RightVBox/LogPanel
@onready var log_label: RichTextLabel = $HudLayer/HudContainer/Margin/MainVBox/MiddleHBox/RightVBox/LogPanel/LogVBox/LogScroll/LogLabel
@onready var draw_pile_sprite: CardPileSprite = $HudLayer/HudContainer/Margin/MainVBox/BottomArea/BottomHBox/DrawPile
@onready var discard_pile_sprite: CardPileSprite = $HudLayer/HudContainer/Margin/MainVBox/BottomArea/BottomHBox/DiscardPile
@onready var hand_fan: HandFan = $HudLayer/HudContainer/Margin/MainVBox/BottomArea/BottomHBox/HandFan
@onready var equipment_bar: EquipmentBar = $HudLayer/HudContainer/Margin/MainVBox/EquipmentBar

# ---- 运行时数据 ----
var players: Array[Player] = []
var _player_teams: Dictionary = {}  # {Player: team_id}
var tile_hud: TilemapHUD

# ---- 交互状态 ----
var selected_card: CardSprite = null
var card_arrow  # CardArrow — 跟踪鼠标的指向箭头
var _arrow_card_sprite: CardSprite = null  # 触发箭头的卡牌 sprite（用于获取屏幕坐标）

# ---- 移动状态机 ----
var _move_mode: bool = false
var _move_source: Player = null
var _move_range: Array[Vector2i] = []


# ============================================================
# 入口
# ============================================================

func _ready() -> void:
    _setup_card_manager()
    _setup_skill_manager()
    _setup_event_system()
    _setup_players()
    _setup_skills()
    _draw_initial_hands()
    _create_tile_hud()
    card_use_requested.connect(_on_card_use_requested)
    move_requested.connect(_on_move_requested)
    # 延迟创建 UI 和启动游戏，确保 viewport 已完成首次布局
    call_deferred("_deferred_start")


# ============================================================
# 系统初始化
# ============================================================

func _deferred_start() -> void:
    # viewport 就绪后连接布局信号和启动游戏
    _resize_hud()
    get_window().size_changed.connect(_resize_hud)

    # 设置静态 UI 组件的初始状态
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    draw_pile_sprite.setup("抽牌堆", card_mgr.get_draw_pile_size())
    draw_pile_sprite.pile_clicked.connect(_on_draw_pile_clicked)
    discard_pile_sprite.setup("弃牌堆", card_mgr.get_discard_pile_size())
    discard_pile_sprite.pile_clicked.connect(_on_discard_pile_clicked)

    # 动态元素
    _create_arrow()

    # 防止 HUD 面板上滚轮缩放地图
    card_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    card_detail_panel.gui_input.connect(_on_panel_gui_input)
    log_panel.mouse_filter = Control.MOUSE_FILTER_PASS
    log_panel.gui_input.connect(_on_panel_gui_input)

    # 装备栏
    equipment_bar.setup(turn_mgr.get_current_player(), self)

    _setup_turn_system()
    _start_game()
    _update_all_ui()


func _setup_card_manager() -> void:
    card_mgr.json_card_database_path = "res://source_codes/data/card_database.json"
    card_mgr.json_card_collection_path = "res://source_codes/data/normal_drawpile.json"
    card_mgr.load_json_path()
    card_mgr.reset()


func _setup_skill_manager() -> void:
    skill_mgr.skill_database_path = "res://source_codes/data/skill_database.json"
    skill_mgr.load_database(skill_mgr.skill_database_path)


func _setup_event_system() -> void:
    event_deck.event_database_path = "res://source_codes/data/event_database.json"
    event_deck.load_database(event_deck.event_database_path)
    event_deck.reset()
    event_mgr.event_deck = event_deck
    # 事件信号 → 日志 + 坐标同步
    event_mgr.event_triggered.connect(_on_event_triggered)
    event_mgr.player_repositioned.connect(_on_player_repositioned)
    event_mgr.global_effect_added.connect(_on_global_effect_added)
    event_mgr.global_effect_removed.connect(_on_global_effect_removed)


func _setup_players() -> void:
    var char_db := _load_json("res://source_codes/data/character_database.json")
    var char_a: Dictionary = _find_char_by_name(char_db, "灰琪")
    var char_b: Dictionary = _find_char_by_name(char_db, "日光耀耀")

    _apply_char_data(player_a, char_a)
    _apply_char_data(player_b, char_b)

    player_a.cube_position = Vector3i(0, 0, 0)
    player_b.cube_position = Vector3i(2, 0, -2)

    # 从 cube_position 推导 map_position（渲染用）
    player_a.map_position = map_node.cube_to_map(player_a.cube_position)
    player_b.map_position = map_node.cube_to_map(player_b.cube_position)

    # 按 map_position 重设玩家世界坐标
    player_a.position = _tile_to_canvas_pos(player_a.map_position)
    player_b.position = _tile_to_canvas_pos(player_b.map_position)

    players = [player_a, player_b]

    # ★ 注入 EventManager 和 all_players 引用到每个 Player
    # DrawCard / UseBaseplay / TurnStart 通过 player.get_meta("event_manager") 访问
    for p in players:
        p.set_meta("event_manager", event_mgr)
        p.set_meta("all_players", players)


func _apply_char_data(p: Player, data: Dictionary) -> void:
    p.player_name = data.get("name", "")
    p.max_health = int(data.get("max_health", 10))
    p.base_health = p.max_health
    p.health = p.max_health
    p.armor = 0  # 默认 0，不由角色库提供
    p.speed = int(data.get("speed", 1))
    p.physical_ability = int(data.get("physical_ability", 1))
    p.magic_ability = int(data.get("magic_ability", 1))
    p.mental_ability = int(data.get("mental_ability", 1))
    p.physical_defence = int(data.get("physical_defence", 0))
    p.magic_defence = int(data.get("magic_defence", 0))
    p.mental_defence = int(data.get("mental_defence", 0))
    p.move_chance = int(data.get("move_chance", 1))
    p.attack_chance = int(data.get("attack_chance", 1))
    p.draw_stage_card_number = int(data.get("draw_stage_card_number", 2))
    p.start_game_draw = int(data.get("start_game_draw", 4))
    p.card_manager = card_mgr

    # 种族
    var species_str: String = data.get("species", "")
    match species_str:
        "EarthPony": p.species = Player.Species.EarthPony
        "Unicorn": p.species = Player.Species.Unicorn
        "Pegasi": p.species = Player.Species.Pegasi
        "Alicon": p.species = Player.Species.Alicon
        _: p.species = Player.Species.others

    # 收藏品
    var coll_ids = data.get("collection_item_ids", [])
    if coll_ids is Array:
        p.collection_item_ids.assign(coll_ids)

    # 技能 id 暂存到 meta，_setup_skills 读取
    p.set_meta("species_skill_ids", data.get("species_skill_ids", []))
    p.set_meta("character_skill_ids", data.get("character_skill_ids", []))


func _find_char_by_name(db: Array, name: String) -> Dictionary:
    for entry in db:
        if entry.get("name") == name:
            return entry
    return {}


func _load_json(path: String) -> Array:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("无法打开 JSON: %s" % path)
        return []
    var text := file.get_as_text()
    var parsed = JSON.parse_string(text)
    if parsed is Array:
        return parsed
    return []


func _setup_skills() -> void:
    for p in players:
        # 种族技能
        var species_ids = p.get_meta("species_skill_ids", [])
        for sid in species_ids:
            var skill = skill_mgr.create_skill(sid)
            if skill:
                p.add_skill(skill)
        # 角色技能
        var char_ids = p.get_meta("character_skill_ids", [])
        for sid in char_ids:
            var skill = skill_mgr.create_skill(sid)
            if skill:
                p.add_skill(skill)
        # 清理 meta
        p.remove_meta("species_skill_ids")
        p.remove_meta("character_skill_ids")


func _draw_initial_hands() -> void:
    # 初始手牌：正常抽牌，事件触发牌进手牌。
    # 当玩家回合开始时，EventTriggerPhase 会自动打出事件触发牌。
    for p in players:
        for i in range(p.start_game_draw):
            if p.is_hand_at_max_capacity():
                break
            var cards = card_mgr.take_from_draw_pile(1)
            if cards.is_empty():
                break
            p.add_card_to_hand(cards[0])


func _create_tile_hud() -> void:
    tile_hud = _TilemapHUD.new()
    $MapLayer.add_child(tile_hud)
    tile_hud.setup(map_node)


func _setup_turn_system() -> void:
    turn_mgr.setup(players)
    _player_teams[player_a] = 0
    _player_teams[player_b] = 1
    turn_mgr.turn_started.connect(_on_turn_started)
    turn_mgr.turn_ended.connect(_on_turn_ended)
    turn_mgr.last_player_standing.connect(_on_last_player_standing)
    for p in players:
        p.collection_finished.connect(_on_collection_finished.bind(p))
        # 连接 ActionTree chain_paused 信号
        var tree = p.get_node_or_null("ActionTree")
        if tree and tree.has_signal("chain_paused"):
            tree.chain_paused.connect(_on_chain_paused)
            # 自动连接所有 action 节点的 action_info 信号
            if not tree.child_entered_tree.is_connected(_on_action_node_added.bind(tree)):
                tree.child_entered_tree.connect(_on_action_node_added.bind(tree))
            for child in tree.get_children():
                _connect_action_info_recursive(child)


func _start_game() -> void:
    turn_mgr.start_game(0)
    _update_all_ui()


## 递归连接 node 及其所有子孙的 action_info 信号
func _connect_action_info_recursive(node: Node) -> void:
    if node.has_signal("action_info") and not node.action_info.is_connected(_on_action_info):
        node.action_info.connect(_on_action_info)
    for child in node.get_children():
        _connect_action_info_recursive(child)


## ActionTree 新子节点进入时自动连接
func _on_action_node_added(node: Node, _tree: Node) -> void:
    _connect_action_info_recursive(node)


## 接收 action 执行信息，转发到战斗日志面板
func _on_action_info(message: String) -> void:
    _log(message)


## 动态创建箭头（每次战斗需新建，不走 tscn）
func _create_arrow() -> void:
    card_arrow = _CardArrow.new()
    card_arrow.name = "CardArrow"
    card_arrow.visible = false
    card_arrow.z_index = 100
    card_layer.add_child(card_arrow)


func _resize_hud() -> void:
    if _hud_container == null:
        return
    if not _hud_container.is_inside_tree():
        call_deferred("_resize_hud")
        return
    var win_size := Vector2(1152, 648)
    var w := get_window()
    if w != null:
        win_size = w.size
    else:
        var ds := DisplayServer.window_get_size()
        win_size = Vector2(ds.x, ds.y)
    _hud_container.set_position(Vector2.ZERO)
    _hud_container.set_size(win_size)


# ============================================================
# 地图控制（WASD 平移 — MapLayer 已处理滚轮缩放）
# ============================================================

const PAN_SPEED := 400.0

func _process(delta: float) -> void:
    if map_layer == null:
        return
    # WASD 平移地图
    var move := Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        move.y += 1
    if Input.is_key_pressed(KEY_S):
        move.y -= 1
    if Input.is_key_pressed(KEY_A):
        move.x += 1
    if Input.is_key_pressed(KEY_D):
        move.x -= 1
    if move != Vector2.ZERO:
        map_layer.offset += move.normalized() * PAN_SPEED * delta

    # 箭头跟随鼠标
    if card_arrow and card_arrow.visible:
        card_arrow.update_target(card_arrow.get_local_mouse_position())


func _input(event: InputEvent) -> void:
    # 键盘快捷键（不受 CanvasLayer 影响）
    if not event is InputEventKey or not event.pressed:
        return

    var controller := turn_mgr.get_current_player()
    if controller == null:
        return

    match event.keycode:
        KEY_M:
            # M 键：进入/退出移动模式
            if _move_mode:
                _exit_move_mode()
                _update_all_ui()
            elif controller.move_chance_in_turn > 0 and not (selected_card and selected_card.card_data):
                _enter_move_mode(controller)
                _update_all_ui()
        KEY_ESCAPE:
            # Esc：取消一切
            if _move_mode:
                _exit_move_mode()
                _update_all_ui()
            elif selected_card:
                _reset_selection()
                card_arrow.deactivate()
                card_detail_label.text = ""
        KEY_SPACE:
            # 空格：结束回合
            _on_end_turn_pressed()


# ============================================================
# 回合回调
# ============================================================

func _on_turn_started(controller: Player) -> void:
    if controller == player_b:
        # 日光耀耀是木桩，自动跳过回合
        turn_mgr.end_current_turn()
        return
    # TurnManager 已触发 TurnStart→DrawCard 链，抽牌由链自动完成
    _log("%s 的回合开始，抽 %d 张牌" % [controller.player_name, controller.draw_stage_card_number])
    _update_all_ui()


func _on_turn_ended(_controller: Player) -> void:
    _update_all_ui()


# ============================================================
# UI 更新
# ============================================================

func _update_all_ui() -> void:
    _update_turn_info()
    _update_hand_display()
    _update_piles()
    _update_tile_hud()
    _update_sprites()
    _update_equipment()
    _update_player_info()
    _check_victory()


func _update_turn_info() -> void:
    var controller := turn_mgr.get_current_player()
    if controller == null:
        return

    round_label.text = "轮次 %d" % max(controller.round_count, 0)
    turn_label.text = "回合 %d" % max(controller.turn_count, 1)
    current_player_label.text = "当前: %s" % controller.player_name


func _update_hand_display() -> void:
    hand_fan.clear_cards()

    var controller := turn_mgr.get_current_player()
    if controller == null:
        return

    for cd in controller.get_hand():
        var cs := CardSprite.new()
        cs.setup(cd)
        cs.card_clicked.connect(_on_card_clicked)
        cs.card_hovered.connect(_on_card_hovered)
        hand_fan.add_card(cs)


func _update_piles() -> void:
    draw_pile_sprite.update_count(card_mgr.get_draw_pile_size())
    discard_pile_sprite.update_count(card_mgr.get_discard_pile_size())


func _update_tile_hud() -> void:
    if tile_hud == null:
        return
    var controller := turn_mgr.get_current_player()
    if controller:
        var team: int = _player_teams.get(controller, -1)
        tile_hud.set_current_player(controller.map_position, team)

    var cells := {}
    for p in players:
        if p.living_state == Player.LivingState.Dead:
            continue
        if not _player_teams.has(p):
            continue
        cells[p.map_position] = _player_teams[p]
    tile_hud.set_player_cells(cells)


func _update_sprites() -> void:
    for p in players:
        p.position = _tile_to_canvas_pos(p.map_position)
        match p.living_state:
            Player.LivingState.Alive:
                p.modulate = Color.WHITE
            Player.LivingState.Fainted:
                p.modulate = Color(1.0, 0.8, 0.3, 0.7)  # 苏醒中：暗黄色
            Player.LivingState.Dead:
                p.modulate = Color(0.3, 0.3, 0.3, 0.6)


func _update_player_info() -> void:
    var controller := turn_mgr.get_current_player()
    if left_panel:
        left_panel.show_player(controller)

func _update_equipment() -> void:
    var controller := turn_mgr.get_current_player()
    if controller:
        equipment_bar.setup(controller, self)


func _check_victory() -> void:
    # 检测死亡玩家并从轮转列表中移除（remove_player 幂等，重复调用无害）
    for p in players:
        if p.living_state == Player.LivingState.Dead:
            turn_mgr.remove_player(p)
            _log("\n[color=#f06060][b]%s 被淘汰！[/b][/color]" % p.player_name)

    # 胜利条件：最后存活
    var alive := turn_mgr.get_alive_count()
    if alive <= 1:
        for p in players:
            if p.living_state != Player.LivingState.Dead:
                _show_victory_popup(p.player_name, "击败了所有对手！")
                return

func _on_last_player_standing(winner: Player) -> void:
    _show_victory_popup(winner.player_name, "击败了所有对手！")


func _on_collection_finished(p: Player) -> void:
    _log("\n[color=#f0d060][b]%s 集齐了 3 个收藏品！[/b][/color]" % p.player_name)


# ---- 事件系统信号处理 ----

func _on_event_triggered(event_card: Resource, triggerer: Player) -> void:
    var name_str = event_card.get("nice_name") if event_card else "未知事件"
    _log("\n[color=#ff6ec7][b]⚡ 事件触发：%s[/b][/color]（触发者：%s）" % [name_str, triggerer.player_name])


func _on_player_repositioned(p: Player, cube_pos: Vector3i) -> void:
    # R6: 坐标系转换在 HudBattle 做
    p.cube_position = cube_pos
    p.map_position = map_node.cube_to_map(cube_pos)
    p.position = _tile_to_canvas_pos(p.map_position)


func _on_global_effect_added(effect: GlobalEffect) -> void:
    var name_str = effect.event_id
    _log("[color=#ff6ec7]全局效果注册：%s[/color]" % name_str)


func _on_global_effect_removed(effect: GlobalEffect) -> void:
    var name_str = effect.event_id
    _log("[color=#888]全局效果移除：%s[/color]" % name_str)


# ---- Chain 暂停处理（技能 HUD 交互）----

func _on_chain_paused(action: BaseAction) -> void:
    var script_path = action.get_script().resource_path
    match script_path:
        "res://source_codes/skills/actions/prospect_entry.gd":
            _show_prospect_dialog(action)
        "res://source_codes/skills/actions/calm_roll_execute.gd":
            _show_dice_choice_dialog(action)
        _:
            _log("[color=#888]未知 chain 暂停: %s[/color]" % script_path)
            var tree = action.get_parent()
            if tree and tree.has_method("resume_chain"):
                tree.resume_chain()


func _show_prospect_dialog(entry: BaseAction) -> void:
    var overlay := _create_dialog_overlay("勘探", "是否使用勘探？(少摸1张牌)")
    var tree = entry.get_parent()
    _add_dialog_button(overlay, "是", func():
        entry.prospect_activated = true
        overlay.queue_free()
        if tree: tree.resume_chain()
    )
    _add_dialog_button(overlay, "否", func():
        entry.prospect_activated = false
        overlay.queue_free()
        if tree: tree.resume_chain()
    )


func _show_dice_choice_dialog(calm: BaseAction) -> void:
    var overlay := _create_dialog_overlay("冷静", "选择一个骰子结果:")
    var tree = calm.get_parent()
    _add_dialog_button(overlay, str(calm.roll1), func():
        calm.chosen = calm.roll1
        overlay.queue_free()
        if tree: tree.resume_chain()
    )
    _add_dialog_button(overlay, str(calm.roll2), func():
        calm.chosen = calm.roll2
        overlay.queue_free()
        if tree: tree.resume_chain()
    )


func _create_dialog_overlay(title: String, body: String) -> PanelContainer:
    var overlay := PanelContainer.new()
    overlay.name = "SkillDialogOverlay"
    overlay.z_index = 200
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0, 0, 0, 0.6)
    overlay.add_theme_stylebox_override("panel", bg)

    var vbox := VBoxContainer.new()
    vbox.name = "VBox"
    vbox.set_anchors_preset(Control.PRESET_CENTER)
    vbox.custom_minimum_size = Vector2(300, 120)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER

    var title_label := RichTextLabel.new()
    title_label.fit_content = true
    title_label.bbcode_enabled = true
    title_label.text = "[center][b][color=#f0d060]%s[/color][/b][/center]" % title
    vbox.add_child(title_label)

    var body_label := Label.new()
    body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body_label.text = body
    vbox.add_child(body_label)

    var btn_hbox := HBoxContainer.new()
    btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_hbox.name = "BtnHBox"
    vbox.add_child(btn_hbox)

    overlay.add_child(vbox)
    card_layer.add_child(overlay)
    return overlay


func _add_dialog_button(overlay: PanelContainer, text: String, callback: Callable) -> void:
    var btn_hbox = overlay.get_node("VBox/BtnHBox")
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(80, 36)
    btn.pressed.connect(callback)
    btn_hbox.add_child(btn)

# ---- 胜利弹窗 ----

func _show_victory_popup(winner_name: String, reason: String) -> void:
    if has_node("VictoryOverlay"):
        return  # 已显示

    var overlay := PanelContainer.new()
    overlay.name = "VictoryOverlay"
    overlay.z_index = 200
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

    # 半透明黑色背景
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0, 0, 0, 0.7)
    overlay.add_theme_stylebox_override("panel", bg)

    var vbox := VBoxContainer.new()
    vbox.name = "VBox"
    vbox.set_anchors_preset(Control.PRESET_CENTER)
    vbox.custom_minimum_size = Vector2(400, 200)

    # 标题
    var title := RichTextLabel.new()
    title.fit_content = true
    title.bbcode_enabled = true
    title.text = "[center][color=#f0d060][font_size=32][b]%s 获胜！[/b][/font_size][/color][/center]" % winner_name
    vbox.add_child(title)

    # 原因
    var reason_label := RichTextLabel.new()
    reason_label.fit_content = true
    reason_label.bbcode_enabled = true
    reason_label.text = "[center]%s[/center]" % reason
    vbox.add_child(reason_label)

    # 间距
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 20)
    vbox.add_child(spacer)

    # 按钮
    var btn := Button.new()
    btn.text = "确定"
    btn.custom_minimum_size = Vector2(120, 40)
    btn.pressed.connect(func():
        overlay.queue_free()
        end_turn_button.disabled = true
    )
    var btn_center := CenterContainer.new()
    btn_center.add_child(btn)
    vbox.add_child(btn_center)

    overlay.add_child(vbox)
    card_layer.add_child(overlay)


# ============================================================
# 交互处理
# ============================================================

func _on_card_clicked(cs: CardSprite) -> void:
    if _move_mode:
        return
    if cs.card_data == null:
        return

    var controller := turn_mgr.get_current_player()
    if controller == null:
        _log("[color=#888]不是你的回合[/color]")
        return

    if selected_card == cs:
        cs.set_selected(false)
        hand_fan.return_card(cs)
        selected_card = null
        _arrow_card_sprite = null
        card_arrow.deactivate()
        card_detail_label.text = ""
        return

    if selected_card:
        selected_card.set_selected(false)
        hand_fan.return_card(selected_card)
    selected_card = cs
    _arrow_card_sprite = cs
    cs.set_selected(true)
    _show_card_detail(cs.card_data)
    _log("选中: %s" % cs.card_data.nice_name)

    # 显示指向箭头
    var card_center := _get_control_center_in_layer(cs, card_layer)
    card_arrow.activate(card_center)


func _on_card_hovered(cs: CardSprite) -> void:
    if cs.card_data == null:
        return
    _show_card_detail(cs.card_data)


func _on_player_clicked(p: Player) -> void:
    if p == null:
        return

    left_panel.show_player(p)
    var controller := turn_mgr.get_current_player()

    # --- 移动模式中：点击移动源角色 → 选择目的地或取消 ---
    if _move_mode:
        if p != _move_source:
            return
        if p.map_position == _move_source.map_position:
            # 再次点击自己 = 取消移动
            _log("[color=#888]取消移动[/color]")
            _exit_move_mode()
            _update_all_ui()
        return

    # --- 正常模式：无选中卡牌 → 点击自己进入移动模式，点击他人查看信息 ---
    if not selected_card or not selected_card.card_data:
        if p == controller and controller.move_chance_in_turn > 0:
            _enter_move_mode(controller)
            _update_all_ui()
        # 点击非自己角色只查看信息（已在上方 left_panel.show_player 处理）
        return

    # --- 有选中卡牌 + 箭头可见 → 使用卡牌 ---
    if not card_arrow or not card_arrow.visible:
        return

    var target_pos := _get_map_pos_in_layer(p, card_layer)
    card_arrow.animate_to_target(target_pos, 0.2, func():
        card_arrow.deactivate()
        var source: Player = turn_mgr.get_current_player()
        card_use_requested.emit(selected_card.card_data, source, p)
    )


func _on_draw_pile_clicked(_ps: CardPileSprite) -> void:
    var controller := turn_mgr.get_current_player()
    if controller == null:
        _log("[color=#888]不是你的回合[/color]")
        return
    # 通过 ActionTree 抽牌
    var tree: Node = controller.get_node_or_null("ActionTree")
    if tree != null and tree.get("draw_card") != null:
        tree.draw_card.draw_num = 1
        tree.chain_of_actions(tree.draw_card)
    _log("抽了 1 张牌")
    _update_all_ui()


func _on_discard_pile_clicked(_ps: CardPileSprite) -> void:
    _log("弃牌堆: %d 张" % card_mgr.get_discard_pile_size())


func _on_end_turn_pressed() -> void:
    if _move_mode:
        _exit_move_mode()
        _update_all_ui()
        return
    _reset_selection()
    card_arrow.deactivate()
    turn_mgr.end_current_turn()


# ============================================================
# 卡牌使用逻辑（由 card_use_requested 信号驱动）
# ============================================================

func _on_card_use_requested(card_data: CardData, source: Player, target: Player) -> void:
    if source == null or target == null or card_data == null:
        return

    # 攻击牌前置检查
    if card_data.type == "Attack":
        if source.attack_chance_in_turn <= 0:
            _log("[color=#f06060]无可用攻击次数！[/color]")
            _reset_selection()
            _update_all_ui()
            return
        if target.immune_from_attack:
            _log("[color=#f0a040]%s 免疫攻击[/color]" % target.player_name)
            _reset_selection()
            _update_all_ui()
            return

    # 走 UseCard 动作链：UseCard → card.execute/resolve → 卡牌生效
    var tree: Node = source.get_node_or_null("ActionTree")
    if tree != null and tree.get("use_card") != null:
        tree.use_card.card = card_data
        tree.use_card.target = target
        tree.chain_of_actions(tree.use_card)

    # attack_chance 递减已在 UseCard.take_action() 中处理

    _log("%s 使用 [%s] → %s" % [source.player_name, card_data.nice_name, target.player_name])
    _reset_selection()
    _update_all_ui()


# ============================================================
# 移动逻辑（由 move_requested 信号驱动）
# ============================================================

func _on_move_requested(target_cell: Vector2i) -> void:
    if _move_source == null:
        return

    # 通过 ActionTree 执行移动
    var tree: Node = _move_source.get_node_or_null("ActionTree")
    if tree != null and tree.get("move_action") != null:
        tree.move_action.target_cell = target_cell
        tree.chain_of_actions(tree.move_action)

    # 同步 cube 坐标（坐标系转换是 HudBattle 的职责）
    _move_source.cube_position = map_node.map_to_cube(target_cell)
    print("[MOVE] %s map_position=%s cube=%s" % [_move_source.player_name, _move_source.map_position, _move_source.cube_position])
    _log("%s 移动到 (%d, %d)" % [_move_source.player_name, target_cell.x, target_cell.y])
    _exit_move_mode()
    _update_all_ui()


func _reset_selection() -> void:
    if selected_card:
        selected_card.set_selected(false)
        hand_fan.return_card(selected_card)
        selected_card = null
    _arrow_card_sprite = null


# ---- 坐标转换辅助 ----
# Player 是 MapLayer (CanvasLayer) 的子节点，所有位置计算使用 CanvasLayer 本地坐标。

## 将地图格坐标转为 CanvasLayer 本地像素坐标（Player.position 用此值）。
## 注意：map_node 有 scale=(2,2)，map_to_local 返回的是未缩放的局部坐标。
func _tile_to_canvas_pos(tile: Vector2i) -> Vector2:
    var local := map_node.map_to_local(tile)
    return map_node.position + local * map_node.scale


func _get_control_center_in_layer(ctrl: Control, _layer: CanvasLayer) -> Vector2:
    return ctrl.get_global_rect().get_center()


func _get_map_pos_in_layer(p: Player, _layer: CanvasLayer) -> Vector2:
    return _tile_to_canvas_pos(p.map_position)


# ============================================================
# 移动系统
# ============================================================

func _enter_move_mode(source: Player) -> void:
    _move_mode = true
    _move_source = source
    # 使用 HexagonTileMapLayer 内置的 cube_range + 过滤 used_cells
    var center_cube: Vector3i = source.cube_position
    var cubes: Array[Vector3i] = map_node.cube_range(center_cube, source.speed)
    _move_range.clear()
    for c in cubes:
        var off: Vector2i = map_node.cube_to_map(c)
        if off != source.map_position and map_node.get_cell_source_id(off) != -1:
            _move_range.append(off)
    tile_hud.set_move_range(_move_range)
    _log("[color=#60a0f0]移动模式：点击蓝色格子移动，右键/Esc 取消[/color]")
    if move_mode_indicator:
        move_mode_indicator.text = "[移动中] 点击目标格"
        move_mode_indicator.visible = true
    end_turn_button.text = "取消移动"


func _exit_move_mode() -> void:
    _move_mode = false
    _move_source = null
    _move_range.clear()
    tile_hud.set_move_range([])
    card_arrow.deactivate()
    _reset_selection()
    if move_mode_indicator:
        move_mode_indicator.visible = false
    end_turn_button.text = "结束回合"


func _unhandled_input(event: InputEvent) -> void:
    # === 只处理鼠标按键 ===
    if not event is InputEventMouseButton or not event.pressed:
        return

    var mouse_global := get_global_mouse_position()

    # DEBUG
    var dbg_tile: Vector2i = _mouse_to_tile(mouse_global)
    var dbg_cube: Vector3i = map_node.map_to_cube(dbg_tile)
    var dbg_local: Vector2 = map_node.get_global_transform_with_canvas().affine_inverse() * mouse_global
    print("[CLICK] global=" + str(mouse_global) + " local=" + str(dbg_local) + " tile=" + str(dbg_tile) + " cube=" + str(dbg_cube) + " zoom=" + str(map_layer.scale) + " off=" + str(map_layer.offset))

    # === 右键：取消一切，清空面板 ===
    if event.button_index == MOUSE_BUTTON_RIGHT:
        if _move_mode:
            _exit_move_mode()
            _update_all_ui()
        elif selected_card:
            _reset_selection()
            card_arrow.deactivate()
            card_detail_label.text = ""
        left_panel.clear()
        get_viewport().set_input_as_handled()
        return

    # === 左键 ===
    if event.button_index != MOUSE_BUTTON_LEFT:
        return

    # 1) 移动模式：点击地图格 → 移动
    if _move_mode:
        var tile_pos := _mouse_to_tile(mouse_global)
        if _move_range.has(tile_pos):
            move_requested.emit(tile_pos)
            get_viewport().set_input_as_handled()
            return

    # 2) 检测是否点击了角色
    var clicked_player := _find_player_at(mouse_global)
    if clicked_player:
        _on_player_clicked(clicked_player)
        get_viewport().set_input_as_handled()
        return

    # 3) 点击空地 → 取消选中
    if selected_card and not _move_mode:
        _reset_selection()
        card_arrow.deactivate()
        card_detail_label.text = ""


# ---- 全局坐标 → 角色 / 格子 ----

## 检测鼠标是否点中角色贴图。
## get_global_transform_with_canvas().affine_inverse() 正确处理 CanvasLayer offset/scale，
## 与 _mouse_to_tile 使用同一个变换路径。
func _find_player_at(mouse_global: Vector2) -> Player:
    for p in players:
        if p.living_state == Player.LivingState.Dead:
            continue
        if p.texture == null:
            continue
        var local_mouse := p.get_global_transform_with_canvas().affine_inverse() * mouse_global
        if p.get_rect().has_point(local_mouse):
            print("[FIND] 点中 %s  rect=%s  local=%s" % [p.player_name, str(p.get_rect()), str(local_mouse)])
            return p
    return null

## 将全局鼠标坐标转换为地图格坐标。
## 通过 get_global_transform_with_canvas().affine_inverse() 抵消 CanvasLayer 的变换，
## 再用 TileMapLayer 的 local_to_map 得到格子坐标。
func _mouse_to_tile(global_pos: Vector2) -> Vector2i:
    var tilemap_local: Vector2 = map_node.get_global_transform_with_canvas().affine_inverse() * global_pos
    return map_node.local_to_map(tilemap_local)


## HUD 面板统一滚轮拦截 — 阻止滚轮穿透到 MapLayer 缩放地图。
func _on_panel_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            get_viewport().set_input_as_handled()


# ============================================================
# 日志
# ============================================================

func _log(msg: String) -> void:
    print(msg)
    if log_label:
        log_label.append_text(msg + "\n")
        # 自动滚动到底部确保新内容可见
        var scroll := log_label.get_parent()
        if scroll is ScrollContainer:
            scroll.call_deferred("set", "scroll_vertical", scroll.get_v_scroll_bar().max_value)


func _show_card_detail(card_data: CardData) -> void:
    if card_data == null:
        return
    var lines: Array[String] = []
    lines.append("[b][color=#f0d060]%s[/color][/b]" % card_data.nice_name)
    lines.append("类型: %s" % card_data.type)
    if card_data.description:
        lines.append("")
        lines.append(card_data.description)
    if card_data.get("goes_to_collection_after_use"):
        lines.append("")
        lines.append("[color=#c080f0]使用后进入收藏品栏[/color]")
    card_detail_label.text = "\n".join(lines)


func _show_skill_detail(skill: SkillData) -> void:
    if skill == null:
        return
    var lines: Array[String] = []
    lines.append("[b][color=#f0d060]%s[/color][/b]" % skill.nice_name)
    var type_str := "主动" if skill.skill_type == SkillData.SkillType.Active else "被动"
    var cat_str := ""
    match skill.category:
        SkillData.Category.Species: cat_str = "种族"
        SkillData.Category.Character: cat_str = "角色"
        SkillData.Category.Equipment: cat_str = "装备"
    lines.append("类型: %s · %s" % [type_str, cat_str])
    if skill.is_disabled():
        lines.append("[color=#f06060][已失效][/color]")
    if skill.description:
        lines.append("")
        lines.append(skill.description)
    card_detail_label.text = "\n".join(lines)


func _clear_detail() -> void:
    card_detail_label.text = ""
