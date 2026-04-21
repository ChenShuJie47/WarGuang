extends SceneTree

const JOBS: Array[Dictionary] = [
	{
		"source": "res://Assets/Dialogues/MerchantDialogue.dialogue",
		"dest": "res://.godot/imported/MerchantDialogue.dialogue-89e52476c4bccfcc39fee034d492941f.tres"
	},
	{
		"source": "res://Assets/Dialogues/MasterDialogue.dialogue",
		"dest": "res://.godot/imported/MasterDialogue.dialogue-f40302c8823c7899e703ad4f2af8a47b.tres"
	},
	{
		"source": "res://Assets/Dialogues/ManiacDialogue.dialogue",
		"dest": "res://.godot/imported/ManiacDialogue.dialogue-e5684801cce5bcaed1fcd2181bed9933.tres"
	},
	{
		"source": "res://Assets/Dialogues/DialoguesNPC4.dialogue",
		"dest": "res://.godot/imported/DialoguesNPC4.dialogue-789cccd08e159e826ba64e6782e4bd76.tres"
	},
]

func _initialize() -> void:
	var config: ConfigFile = ConfigFile.new()
	var version: String = "3.10.2"
	if config.load("res://addons/dialogue_manager/plugin.cfg") == OK:
		version = str(config.get_value("plugin", "version", version))

	var compiler_script: GDScript = load("res://addons/dialogue_manager/compiler/compiler.gd")
	var dialogue_resource_script: GDScript = load("res://addons/dialogue_manager/dialogue_resource.gd")
	var had_error: bool = false

	for job in JOBS:
		var source_path: String = job["source"]
		var dest_path: String = job["dest"]
		var raw_text: String = FileAccess.get_file_as_string(source_path)
		if raw_text.is_empty() and not FileAccess.file_exists(source_path):
			push_error("Missing dialogue source: %s" % source_path)
			had_error = true
			continue

		var result: DMCompilerResult = compiler_script.compile_string(raw_text, source_path)
		if result.errors.size() > 0:
			push_error("Dialogue compile errors in %s: %s" % [source_path, result.errors])
			had_error = true
			continue

		var resource: DialogueResource = dialogue_resource_script.new()
		resource.set_meta("dialogue_manager_version", version)
		resource.using_states = result.using_states
		resource.titles = result.titles
		resource.first_title = result.first_title
		resource.character_names = result.character_names
		resource.lines = result.lines
		resource.raw_text = result.raw_text

		var save_error: Error = ResourceSaver.save(resource, dest_path)
		if save_error != OK:
			push_error("Failed to save %s to %s (error %s)" % [source_path, dest_path, save_error])
			had_error = true
			continue

		print("Rebuilt dialogue import: %s" % dest_path)

	quit(1 if had_error else 0)