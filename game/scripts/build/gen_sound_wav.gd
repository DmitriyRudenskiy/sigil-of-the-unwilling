extends SceneTree

const OUT_DIR := "res://assets/audio/"

func _init() -> void:
    print("=== Sound Synthesizer ===")
    if not DirAccess.dir_exists_absolute(OUT_DIR):
        DirAccess.make_dir_recursive_absolute(OUT_DIR)

    _generate("ui_click", 0.05, 800.0, 0.0)
    _generate("attack_hit", 0.15, 150.0, 0.5)
    _generate("unit_death", 0.4, 400.0, -15.0)
    _generate("pickup_item", 0.2, 1200.0, 5.0)
    _generate("bgm_loop", 4.0, 220.0, 0.0)

    print("Done. Generated WAVs in %s" % OUT_DIR)
    quit(0)

func _generate(name: String, duration: float, base_freq: float, freq_slope: float) -> void:
    var sample_rate := 22050
    var num_samples := int(duration * sample_rate)
    var data := PackedByteArray()
    data.resize(num_samples * 2)

    var phase := 0.0
    for i in num_samples:
        var t := float(i) / float(sample_rate)
        var freq := base_freq + (freq_slope * t)
        phase += freq / float(sample_rate)
        var wave := sin(phase * TAU)

        if name == "attack_hit":
            wave = (wave * 0.3) + (randf_range(-1.0, 1.0) * 0.7)

        var env := 1.0 - (float(i) / float(num_samples))
        wave *= env * 0.8

        var sample_val := int(wave * 32767.0)
        data[i * 2] = sample_val & 0xFF
        data[i * 2 + 1] = (sample_val >> 8) & 0xFF

    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = sample_rate
    wav.stereo = false
    wav.data = data

    var path := OUT_DIR + name + ".wav"
    ResourceSaver.save(wav, path)
    print("  Saved: %s" % path)
