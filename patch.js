const fs = require('fs');

// Patch Animation Service
let file = fs.readFileSync('Scripts/Player/PlayerAnimationService.gd', 'utf8');
const rx = /(\t*)player\.PlayerState\.RUN:\r?\n\t*target_animation_val = .RUN./;
file = file.replace(rx, '$1player.PlayerState.RUN:\n$1\ttarget_animation_val = "RUN"\n$1player.PlayerState.BACKSTEP:\n$1\ttarget_animation_val = _resolve_backstep_animation(player)');

file += `

static func _resolve_backstep_animation(player: Node) -> String:
	var entry_name: String = String(player.backstep_entry_animation_name)
	var loop_name: String = String(player.backstep_loop_animation_name)
	var fallback_name: String = String(player.backstep_fallback_animation_name)
	var sprite_frames = player.animated_sprite.sprite_frames
	
	var is_entry_capable: bool = sprite_frames and sprite_frames.has_animation(entry_name)
	var is_loop_capable: bool = sprite_frames and sprite_frames.has_animation(loop_name)
	
	if is_entry_capable:
		if player.current_animation != entry_name and player.current_animation != loop_name:
			return entry_name
		
		if player.current_animation == entry_name:
			var is_finished = false
			if not player.animated_sprite.is_playing() and player.animated_sprite.frame == sprite_frames.get_frame_count(entry_name) - 1:
				is_finished = true
			
			if not is_finished:
				return entry_name
	
	if is_loop_capable:
		return loop_name
		
	if sprite_frames and sprite_frames.has_animation(fallback_name):
		return fallback_name
	return "DASH"
`;

fs.writeFileSync('Scripts/Player/PlayerAnimationService.gd', file);
console.log('done animation patching');


// Patch Movement Service
let mvFile = fs.readFileSync('Scripts/Player/PlayerMovementService.gd', 'utf8');

// Insert handle_backstep_state
const bumpRegex = /(\t*)# 处理攀墙状态的受力、减速和跳跃入口/; // fallback to English if missing, but we will find `static func handle_wallgrip_state`
const insertHandleWallgrip = mvFile.indexOf('static func handle_wallgrip_state');
if (insertHandleWallgrip !== -1) {
	const textToInsert = `static func handle_backstep_state(player: Node) -> void:
	var direction: int = player.backstep_direction
	if direction == 0:
		direction = -1 if player.is_facing_right else 1
		player.backstep_direction = direction
	player.velocity.x = direction * player.backstep_speed * player.effective_horizontal_multiplier
	player.velocity.y = 0.0

`;
	mvFile = mvFile.slice(0, insertHandleWallgrip) + textToInsert + mvFile.slice(insertHandleWallgrip);
}

// Insert try_backstep
const insertHandleIdle = mvFile.indexOf('static func handle_idle_state');
if (insertHandleIdle !== -1) {
	const tryBackstepStr = `static func try_backstep(player: Node, move_input: float) -> bool:
	if not player.backstep_unlocked or not player.can_backstep:
		return false
	if not (player.is_on_floor() or player.coyote_time_active):
		return false

	if player.current_state != player.PlayerState.MOVE and player.current_state != player.PlayerState.RUN:
		return false

	if move_input == 0.0:
		return false

	var opposite_input: bool = false
	if player.is_facing_right:
		opposite_input = move_input < 0.0
	else:
		opposite_input = move_input > 0.0
		
	if opposite_input:
		player.can_backstep = false
		player.change_state(player.PlayerState.BACKSTEP)
		return true
	return false

`;
	mvFile = mvFile.slice(0, insertHandleIdle) + tryBackstepStr + mvFile.slice(insertHandleIdle);
}

// Call try_backstep in idle, move, run
const idleTarget = 'if try_dash(player, dash_just_pressed):';
mvFile = mvFile.split(idleTarget).join('if try_backstep(player, move_input):\n\t\treturn\n\n\t' + idleTarget);

// Add dash timer for backstep
const timerBlockRegex = /if player.current_state == player.PlayerState.DASH:[\s\S]*?(?=\nstatic func _check_game_pause_state)/;
const dashTimerMatch = mvFile.match(timerBlockRegex);
if (dashTimerMatch) {
	const backstepTimerStr = `

	if player.current_state == player.PlayerState.BACKSTEP:
		player.backstep_duration_timer += fixed_delta
		if player.backstep_duration_timer >= maxf(player.backstep_duration, 0.01):
			player.backstep_duration_timer = 0.0
			if player.is_on_floor() or player.coyote_time_active:   
				var move_input_after_backstep: float = Input.get_axis("left", "right")
				if move_input_after_backstep == 0:
					player.change_state(player.PlayerState.IDLE)
				elif player.is_running:
					player.change_state(player.PlayerState.RUN)
				else:
					player.change_state(player.PlayerState.MOVE)
			else:
				player.change_state(player.PlayerState.DOWN)    

	if not player.can_backstep:
		player.backstep_cooldown_timer += fixed_delta
		if player.backstep_cooldown_timer >= maxf(player.backstep_cooldown, 0.01):
			player.backstep_cooldown_timer = 0.0
			player.can_backstep = true`;
	
	const newMatch = dashTimerMatch[0] + backstepTimerStr;
	mvFile = mvFile.replace(dashTimerMatch[0], newMatch);
}

fs.writeFileSync('Scripts/Player/PlayerMovementService.gd', mvFile);
console.log('done movement patching');

// Clean Scene Cinematic Errors
// NewSaveOpeningEventDirector
let openingFile = fs.readFileSync('Scripts/GameScenes/NewSaveOpeningEventDirector.gd', 'utf8');

const regexWait = /boot_cinematic_director\.play_intro_sequence\(opening_payload\)[\s\S]*?(?=_opening_running = false)/;
const replaceWait = `boot_cinematic_director.play_intro_sequence(opening_payload)
	_ensure_global_black_revealed(0.0)
	boot_cinematic_director.start_gameplay_drop(player, opening_payload)    
	`;
openingFile = openingFile.replace(regexWait, replaceWait);
fs.writeFileSync('Scripts/GameScenes/NewSaveOpeningEventDirector.gd', openingFile);

// RoomCinematicEventDirector
let roomCinematicFile = fs.readFileSync('Scripts/GameScenes/RoomCinematicEventDirector.gd', 'utf8');
const badCinematicSync = /await cinematic_director.play_blocking_intro_event[\s\S]*?(?=_event_running = false)/;
const cleanedCinematicSync = `await cinematic_director.play_blocking_intro_event(player, {
		"sequence_steps": runtime_steps,
		"reveal_duration": float(timing_defaults.get("fade_duration", 0.5)),
		"pause_world": pause_world_during_event
	})

	if Global and Global.has_method("set_cinematic_flag"):
		Global.set_cinematic_flag(trigger_flag_id, true)
		if SaveManager and Global.current_save_slot >= 0 and SaveManager.has_method("save_game"):
			SaveManager.save_game(Global.current_save_slot, Global.get_save_data())
	`;
roomCinematicFile = roomCinematicFile.replace(badCinematicSync, cleanedCinematicSync);
fs.writeFileSync('Scripts/GameScenes/RoomCinematicEventDirector.gd', roomCinematicFile);

console.log('done cinematic cleaning');
