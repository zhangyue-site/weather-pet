@tool
extends EditorPlugin
class FrameExporter extends EditorExportPlugin:
	func _get_name() -> String: return "CompanionFrames"
	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		# Pair poses decode raw PNG at runtime. Imported texture export alone
		# makes both actors disappear when a duet switches onto this atlas.
		var poses := "res://companion/art/interaction-poses-v1.png"
		add_file(poses, FileAccess.get_file_as_bytes(poses), false)
		var base := "res://companion/fish/"
		var manifest_path := base + "manifest.json"
		if not FileAccess.file_exists(manifest_path):
			push_error("Fish animation manifest is missing")
			return
		add_file(manifest_path, FileAccess.get_file_as_bytes(manifest_path), false)
		add_file(base + "LICENSE-upstream.txt", FileAccess.get_file_as_bytes(base + "LICENSE-upstream.txt"), false)
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		for animation in manifest:
			for index in range(int(manifest[animation].frames)):
				var resource_path := base + String(animation) + "/f%03d.webp" % index
				add_file(resource_path, FileAccess.get_file_as_bytes(resource_path), false)
var exporter: FrameExporter
func _enter_tree() -> void:
	exporter = FrameExporter.new()
	add_export_plugin(exporter)
func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
