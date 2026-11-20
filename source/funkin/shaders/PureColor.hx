package funkin.shaders;

import flixel.system.FlxAssets.FlxShader;

class PureColor extends FlxShader
{
	public var col(default, set):FlxColor;
	public var colorSet(default, set):Bool;

	function set_colorSet(value:Bool):Bool
	{
		colSet.value = [value];
		return colorSet = value;
	}

	function set_col(value:FlxColor):FlxColor
	{
		funnyColor.value = [value.redFloat, value.greenFloat, value.blueFloat, value.alphaFloat];
		return col = value;
	}

	@:glFragmentSource('
		#pragma header

		uniform vec4 funnyColor;
		uniform bool colSet;

		void main()
		{
			vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);
			if (color.a > 0.0 && colSet)
				color = funnyColor * color.a;
			gl_FragColor = color;
		}
	')
	public function new(color:FlxColor)
	{
		super();
		col = color;
		colorSet = false;
	}
}
