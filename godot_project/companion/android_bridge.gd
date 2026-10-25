extends RefCounted
# Godot4.4's Java wrapper has a shared class cache and exception slot.
# Serialize app bridge calls; rendering code only tries the lock and uses cache if busy.
static var mutex := Mutex.new()
