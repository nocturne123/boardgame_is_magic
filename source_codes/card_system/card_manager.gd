class_name CardManager
extends Node

## 管理抽牌堆和弃牌堆，提供卡牌创建与查询。
## 手牌交由各 Player 自行管理。

enum Piles {
    draw_pile,
    discard_pile,
}

# ---- 信号 ----

signal draw_pile_updated
signal discard_pile_updated
signal card_drawn(card_data: CardData)
signal card_discarded(card_data: CardData)

# ---- 配置 ----

@export_file("*.json") var json_card_database_path: String
@export_file("*.json") var json_card_collection_path: String
@export var shuffle_discard_on_empty_draw := true
## 是否在初始化时洗牌。false=按 JSON 顺序抽（测试用），true=随机洗牌。
@export var shuffle_draw_pile: bool = false

# ---- 内部状态 ----

var card_database: Array = []   ## 原始 JSON 数组，每项为 Dictionary
var card_collection: Array = [] ## 初始抽牌堆的 nice_name 列表

var _draw_pile: Array[CardData] = []
var _discard_pile: Array[CardData] = []

# ---- JSON 加载 ----

func _ready() -> void:
    load_json_path()
    _reset_card_collection()

func load_json_path() -> void:
    card_database = _load_json_array(json_card_database_path)
    card_collection = _load_json_array(json_card_collection_path)

func _load_json_array(path: String) -> Array:
    if path.is_empty():
        return []
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("CardManager: 无法打开 JSON 文件: %s" % path)
        return []
    var text := file.get_as_text()
    var parsed = JSON.parse_string(text)
    if parsed is Array:
        return parsed
    return []

# ---- 初始化与重置 ----

func reset() -> void:
    _reset_card_collection()

func _reset_card_collection() -> void:
    _draw_pile.clear()
    _discard_pile.clear()

    for nice_name in card_collection:
        var json_data := _get_json_entry_by_nice_name(nice_name)
        if json_data.is_empty():
            push_warning("CardManager: 卡牌 '%s' 在数据库中未找到" % nice_name)
            continue
        var c: CardData = _create_card_data(json_data)
        _draw_pile.push_back(c)

    if shuffle_draw_pile:
        _draw_pile.shuffle()
    draw_pile_updated.emit()
    discard_pile_updated.emit()

# ---- 核心 API ----

## 从抽牌堆取 count 张牌（不管理手牌，调用方自行处理）。
func take_from_draw_pile(count: int = 1) -> Array[CardData]:
    var cards: Array[CardData] = []
    for _i in range(count):
        if _draw_pile.is_empty() and shuffle_discard_on_empty_draw:
            _shuffle_discard_into_draw()
        if _draw_pile.is_empty():
            return cards
        var card: CardData = _draw_pile.pop_back()
        cards.push_back(card)
        card_drawn.emit(card)
    draw_pile_updated.emit()
    return cards

## 将卡牌收入弃牌堆。
func receive_into_discard(card_data: CardData) -> void:
    if card_data == null:
        return
    _remove_from_piles(card_data)
    _discard_pile.push_back(card_data)
    card_discarded.emit(card_data)
    discard_pile_updated.emit()

## 将卡牌彻底移出游戏。
func remove_from_game(card_data: CardData) -> void:
    if card_data == null:
        return
    _remove_from_piles(card_data)

## 将卡牌放入指定堆（仅 draw_pile / discard_pile）。
func set_card_pile(card_data: CardData, pile: Piles) -> void:
    if card_data == null:
        return
    _remove_from_piles(card_data)
    match pile:
        Piles.draw_pile:
            _draw_pile.push_back(card_data)
            draw_pile_updated.emit()
        Piles.discard_pile:
            _discard_pile.push_back(card_data)
            discard_pile_updated.emit()

## 按 nice_name 创建一张新卡牌实例并返回。调用方自行决定去向。
func create_card(nice_name: String) -> CardData:
    var json_data := _get_json_entry_by_nice_name(nice_name)
    if json_data.is_empty():
        push_warning("CardManager: 无法创建卡牌 '%s'，数据库中未找到" % nice_name)
        return null
    return _create_card_data(json_data)

# ---- 查询 API ----

func get_cards_in_draw_pile() -> Array[CardData]:
    return _draw_pile.duplicate()

func get_cards_in_discard_pile() -> Array[CardData]:
    return _discard_pile.duplicate()

func get_draw_pile_size() -> int:
    return _draw_pile.size()

## 翻看抽牌堆顶牌（不抽出）。供勘探等技能使用。
func peek_draw_pile() -> CardData:
    if _draw_pile.is_empty():
        return null
    return _draw_pile[_draw_pile.size() - 1]

func get_discard_pile_size() -> int:
    return _discard_pile.size()

## 根据 identity 字符串查询卡牌数据库中的原始 JSON 条目。
func get_card_data_by_identity(identity: String) -> Dictionary:
    for json_data in card_database:
        if json_data.get("identity") == identity:
            return json_data
    return {}

# ---- 内部辅助 ----

func _get_json_entry_by_nice_name(nice_name: String) -> Dictionary:
    if nice_name.is_empty():
        return {}
    for json_data in card_database:
        if json_data.get("nice_name") == nice_name:
            return json_data
    return {}

func _create_card_data(json_data: Dictionary) -> CardData:
    var script_path: String = json_data.get("resource_script_path", "")
    var card_data: CardData
    if script_path.is_empty():
        card_data = CardData.new()
    else:
        var script_resource := load(script_path)
        if script_resource == null:
            push_error("CardManager: 无法加载卡牌脚本: %s" % script_path)
            card_data = CardData.new()
        else:
            card_data = script_resource.new()
    for key in json_data.keys():
        match key:
            "resource_script_path", "backface_texture_path":
                continue
            "skill_ids":
                var ids = json_data[key]
                if ids is Array:
                    card_data.skill_ids.assign(ids)
            _:
                card_data.set(key, json_data[key])
    return card_data

func _remove_from_piles(card_data: CardData) -> void:
    if card_data == null:
        return
    if _draw_pile.has(card_data):
        _draw_pile.erase(card_data)
        draw_pile_updated.emit()
    if _discard_pile.has(card_data):
        _discard_pile.erase(card_data)
        discard_pile_updated.emit()

func _shuffle_discard_into_draw() -> void:
    while not _discard_pile.is_empty():
        _draw_pile.push_back(_discard_pile.pop_back())
    _draw_pile.shuffle()
    draw_pile_updated.emit()
    discard_pile_updated.emit()
