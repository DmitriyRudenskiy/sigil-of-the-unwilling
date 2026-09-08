extends RefCounted
class_name ParticlePresets

static func spawn_burst(parent: Node2D, pos: Vector2, color: Color) -> void:
    if OS.has_feature("headless"):
        return
    var p := GPUParticles2D.new()
    p.emitting = true
    p.one_shot = true
    p.amount = 12
    p.lifetime = 0.4
    p.position = pos
    
    var mat := ParticleProcessMaterial.new()
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 180.0
    mat.initial_velocity_min = 50.0
    mat.initial_velocity_max = 100.0
    mat.gravity = Vector3(0, 200, 0)
    mat.color = color
    p.process_material = mat
    parent.add_child(p)
    p.finished.connect(p.queue_free)
