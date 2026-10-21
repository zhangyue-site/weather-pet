package com.weather.companion

/** Separate provider so Godot's own FileProvider keeps its original paths. */
class UpdateFileProvider : androidx.core.content.FileProvider()
