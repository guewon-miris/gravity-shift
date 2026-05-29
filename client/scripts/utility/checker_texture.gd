class_name CheckerTexture
extends RefCounted

## Generates a 2-color checker ImageTexture for use on Sprite2D / TextureRect.
static func make_texture(primary: Color, secondary: Color, tiles: int = 4, px: int = 16) -> ImageTexture:
	var size := tiles * px
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var ty := y / px
		for x in size:
			var tx := x / px
			var c := primary if ((tx + ty) & 1) == 0 else secondary
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	tex.resource_name = "Checker_%s_%s" % [primary, secondary]
	return tex

## Rectangular cols x rows checkerboard (one texel tile per grid cell, scaled by px).
static func make_board(cols: int, rows: int, primary: Color, secondary: Color, px: int = 8) -> ImageTexture:
	var w := cols * px
	var h := rows * px
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var ty := y / px
		for x in w:
			var tx := x / px
			var c := primary if ((tx + ty) & 1) == 0 else secondary
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
