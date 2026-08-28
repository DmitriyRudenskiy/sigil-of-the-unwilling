extends RefCounted
class_name PlaceholderTexture
## Кэшированные заглушки-круги для спрайтов без портретов.

static var _cache: Dictionary = {}

static func circle(radius: int, fill: Color, border: Color) -> ImageTexture:
	var key := "%d_%s_%s" % [radius, fill.to_html(), border.to_html()]

	if _cache.has(key):
		return _cache[key]

	var size := radius * 2 + 4
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)

	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center)

			if d <= radius:
				img.set_pixel(x, y, fill)
			elif d <= radius + 2:
				img.set_pixel(x, y, border)

	var texture := ImageTexture.create_from_image(img)
	_cache[key] = texture
	return texture
