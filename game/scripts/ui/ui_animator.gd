extends Node
class_name UIAnimator

static func animate_in(control: Control, duration: float = 0.2) -> void:
    control.modulate.a = 0.0
    control.position.y += 20.0
    var tw := control.create_tween()
    tw.set_parallel(true)
    tw.tween_property(control, "modulate:a", 1.0, duration)
    tw.tween_property(control, "position:y", control.position.y - 20.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

static func animate_out(control: Control, duration: float = 0.15) -> void:
    var tw := control.create_tween()
    tw.set_parallel(true)
    tw.tween_property(control, "modulate:a", 0.0, duration)
    tw.tween_property(control, "position:y", control.position.y + 20.0, duration)
    tw.chain().tween_callback(control.hide)

const SETUP_META := &"ui_animator_setup"

static func setup_button(btn: Button) -> void:
    if btn.has_meta(SETUP_META):
        return
    btn.set_meta(SETUP_META, true)
    btn.pivot_offset = btn.size / 2.0
    btn.mouse_entered.connect(func():
        var tw = btn.create_tween()
        tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
    )
    btn.mouse_exited.connect(func():
        var tw = btn.create_tween()
        tw.tween_property(btn, "scale", Vector2.ONE, 0.1)
    )
    btn.button_down.connect(func():
        var tw = btn.create_tween()
        tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
    )
    btn.button_up.connect(func():
        var tw = btn.create_tween()
        tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.05)
    )
