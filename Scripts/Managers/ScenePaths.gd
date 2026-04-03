# Scripts/Resources/ScenePaths.gd
extends Node
## 全局场景路径管理器
## 集中管理所有场景和资源路径
## 避免硬编码路径分散在各处

# ============================================
# UI 场景路径常量
# ============================================
const UI_TITLE = "res://Scenes/UI/Scenes/TitleScene.tscn"
const UI_SAVE_SELECT = "res://Scenes/UI/Scenes/SaveSelectScene.tscn"
const UI_SETTINGS = "res://Scenes/UI/Scenes/SettingsScene.tscn"
const UI_GAME_SETTING = "res://Scenes/UI/Scenes/GameSettingScene.tscn"
const UI_DELETE_CONFIRM = "res://Scenes/UI/Scenes/DeleteConfirmDialog.tscn"
const UI_CHALLENGE_COUNTER = "res://Scenes/UI/ChallengeCounter.tscn"
const UI_MY_BALLOON = "res://Scenes/UI/MyBalloon.tscn"
const UI_DARK_OVERLAY = "res://Scenes/Managers/DarkOverlay.tscn"

# ============================================
# 玩家相关场景
# ============================================
const PLAYER_HEALTH_UNIT = "res://Scenes/Player/HealthUnit.tscn"
const PLAYER_UI = "res://Scenes/Player/PlayerUI.tscn"
const PLAYER_AFTERIMAGE = "res://Scenes/Instances/Afterimage.tscn"

# ============================================
# NPC 场景
# ============================================
const NPC_MANIAC = "res://Scenes/NPCs/ManiacNPC.tscn"
const NPC_MERCHANT = "res://Scenes/NPCs/MerchantNPC.tscn"
const NPC_MASTER = "res://Scenes/NPCs/MasterNPC.tscn"

# ============================================
# 游戏主场景
# ============================================
const GAME_MAIN = "res://Scenes/GameScenes/MainGameScene.tscn"
const GAME_ROOM1 = "res://Scenes/GameScenes/Room1.tscn"

# ============================================
# 快捷加载方法（可选，但更方便）
# ============================================
static func load_title() -> PackedScene:
	return load(UI_TITLE)

static func load_save_select() -> PackedScene:
	return load(UI_SAVE_SELECT)

static func load_settings() -> PackedScene:
	return load(UI_SETTINGS)

static func load_game_setting() -> PackedScene:
	return load(UI_GAME_SETTING)

static func load_delete_confirm() -> PackedScene:
	return load(UI_DELETE_CONFIRM)

static func load_challenge_counter() -> PackedScene:
	return load(UI_CHALLENGE_COUNTER)

static func load_my_balloon() -> PackedScene:
	return load(UI_MY_BALLOON)

static func load_dark_overlay() -> PackedScene:
	return load(UI_DARK_OVERLAY)

static func load_health_unit() -> PackedScene:
	return load(PLAYER_HEALTH_UNIT)

static func load_player_ui() -> PackedScene:
	return load(PLAYER_UI)

static func load_afterimage() -> PackedScene:
	return load(PLAYER_AFTERIMAGE)

static func load_maniac() -> PackedScene:
	return load(NPC_MANIAC)

static func load_merchant() -> PackedScene:
	return load(NPC_MERCHANT)

static func load_master() -> PackedScene:
	return load(NPC_MASTER)

static func load_main_game() -> PackedScene:
	return load(GAME_MAIN)

static func load_room1() -> PackedScene:
	return load(GAME_ROOM1)
