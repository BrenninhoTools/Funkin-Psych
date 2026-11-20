package funkin.shaders;

import flixel.system.FlxAssets.FlxShader;

class StrokeShader extends FlxShader
{
	public var width(default, set):Float = 0;
	public var height(default, set):Float = 0;
	public var col(default, set):FlxColor = 0xFFFFFFFF;

	function set_width(value:Float):Float
	{
		size.value = [value, height];
		return width = value;
	}

	function set_height(value:Float):Float
	{
		size.value = [width, value];
		return height = value;
	}

	function set_col(value:FlxColor):FlxColor
	{
		color.value = [value.redFloat, value.greenFloat, value.blueFloat, value.alphaFloat];
		return col = value;
	}

	@:glFragmentSource('
		#pragma header

		uniform vec2 size;
		uniform vec4 color;

		void main()
		{
			vec4 pixel = flixel_texture2D(bitmap, openfl_TextureCoordv);
			if (pixel.a == 0.0)
			{
				float w = size.x / openfl_TextureSize.x;
				float h = size.y / openfl_TextureSize.y;
				if (flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x + w, openfl_TextureCoordv.y)).a != 0.0
				|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x - w, openfl_TextureCoordv.y)).a != 0.0
				|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x, openfl_TextureCoordv.y + h)).a != 0.0
				|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x, openfl_TextureCoordv.y - h)).a != 0.0)
					pixel = color;
			}
			gl_FragColor = pixel;
		}
	')
	public function new(color:FlxColor = 0xFFFFFFFF, width:Float = 1, height:Float = 1)
	{
		super();
		col = color;
		this.width = width;
		this.height = height;
	}
}
