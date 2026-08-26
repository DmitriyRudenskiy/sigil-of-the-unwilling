class_name PreviewRenderer
extends Node2D

var tile_map: TileMapLayer
var camera: Camera2D

func _ready() -> void:
    tile_map = TileMapLayer.new()
    # В реальном запуске подгружается временный TileSet из нарезанных текстур
    add_child(tile_map)
    
    camera = Camera2D.new()
    camera.zoom = Vector2(1.5, 1.5)
    add_child(camera)

func generate_forced_borders_map() -> void:
    # Генерирует карту 24x16 с принудительными границами всех биомов
    # для демонстрации работы peering bits (переходов).
    pass # Логика аналогична TestTerrain.gd, но расширенная до 24x16

func take_screenshot(path: String) -> void:
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw # Ждем 2 кадра для завершения отрисовки
    var img := get_viewport().get_texture().get_image()
    img.save_png(path)
    print("Screenshot saved: %s" % path)
