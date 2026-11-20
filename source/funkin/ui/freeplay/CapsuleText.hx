package funkin.ui.freeplay;

import flixel.addons.display.FlxRuntimeShader;
import flixel.math.FlxRect;
import openfl.display.BlendMode;
import openfl.filters.BitmapFilterQuality;
import openfl.filters.GlowFilter;

class CapsuleText extends FlxSpriteGroup
{
	static var blurSource:String = null;

	public var blurredText:FlxText;
	public var text(default, set):String;
	public var clipWidth(default, set):Int = 255;
	public var tooLong:Bool = false;

	var whiteText:FlxText;
	var glowColor:FlxColor = 0xFF00CCFF;
	var moveTimer:FlxTimer = new FlxTimer();
	var moveTween:FlxTween;
	var flickerTimer:FlxTimer;
	var flickerState:Bool = false;

	public function new(x:Float, y:Float, songTitle:String, size:Float)
	{
		super(x, y);
		blurredText = makeText(songTitle, size);
		var blur:FlxRuntimeShader = makeBlur();
		if (blur != null) blurredText.shader = blur;
		whiteText = makeText(songTitle, size);
		blurredText.color = glowColor;
		whiteText.color = 0xFFFFFFFF;
		add(blurredText);
		add(whiteText);
		text = songTitle;
	}

	static function makeText(title:String, size:Float):FlxText
	{
		var field:FlxText = new FlxText(0, 0, 0, title, Std.int(size));
		field.font = Paths.font('5by7.ttf');
		field.antialiasing = Save.data.antialiasing;
		return field;
	}

	static function makeBlur():FlxRuntimeShader
	{
		if (blurSource == null) blurSource = Paths.getTextFromFile('shaders/gaussianBlur.frag');
		if (blurSource == null) return null;
		try
		{
			var shader:FlxRuntimeShader = new FlxRuntimeShader(blurSource);
			shader.setFloat('_amount', 1);
			return shader;
		}
		catch (e:Dynamic)
		{
			blurSource = null;
			return null;
		}
	}

	public function applyStyle(color:FlxColor):Void
	{
		glowColor = color;
		blurredText.color = glowColor;
		applyGlow(glowColor);
	}

	inline function applyGlow(color:FlxColor)
		whiteText.textField.filters = [new GlowFilter(color.rgb, 1, 5, 5, 210, BitmapFilterQuality.MEDIUM)];

	function set_clipWidth(value:Int):Int
	{
		clipWidth = value;
		resetText();
		checkClipWidth();
		return value;
	}

	function checkClipWidth():Void
	{
		if (whiteText == null || blurredText == null) return;
		if (whiteText.width > clipWidth)
		{
			tooLong = true;
			blurredText.clipRect = new FlxRect(0, 0, clipWidth, blurredText.height);
			whiteText.clipRect = new FlxRect(0, 0, clipWidth, whiteText.height);
		}
		else
		{
			tooLong = false;
			blurredText.clipRect = null;
			whiteText.clipRect = null;
		}
	}

	function set_text(value:String):String
	{
		if (value == null) return value;
		text = value;
		if (blurredText == null || whiteText == null) return value;
		blurredText.text = value;
		whiteText.text = value;
		checkClipWidth();
		applyGlow(glowColor);
		return value;
	}

	public function initMove():Void
	{
		moveTimer.start(0.6, function(_) moveText(true));
	}

	function moveText(right:Bool):Void
	{
		moveTween = FlxTween.tween(whiteText.offset, {x: right ? whiteText.width - clipWidth : 0}, 2, {
			ease: FlxEase.sineInOut,
			onUpdate: function(_)
			{
				whiteText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, whiteText.height);
				blurredText.offset.x = whiteText.offset.x;
				blurredText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, blurredText.height);
			},
			onComplete: function(_) moveTimer.start(0.3, function(_) moveText(!right))
		});
	}

	public function resetText():Void
	{
		scale.set(1, 1);
		if (moveTween != null) moveTween.cancel();
		if (moveTimer != null) moveTimer.cancel();
		if (whiteText == null) return;
		whiteText.offset.x = 0;
		blurredText.offset.x = 0;
		if (tooLong)
		{
			whiteText.clipRect = new FlxRect(0, 0, clipWidth, whiteText.height);
			blurredText.clipRect = new FlxRect(0, 0, clipWidth, blurredText.height);
		}
	}

	public function flickerText():Void
	{
		resetText();
		flickerTimer = new FlxTimer().start(1 / 24, flickerProgress, 19);
	}

	function flickerProgress(_):Void
	{
		if (flickerState)
		{
			whiteText.blend = BlendMode.ADD;
			blurredText.blend = BlendMode.ADD;
			blurredText.color = 0xFFFFFFFF;
			whiteText.color = 0xFFFFFFFF;
			applyGlow(0xFFFFFFFF);
		}
		else
		{
			blurredText.color = glowColor;
			whiteText.color = 0xFFDDDDDD;
			applyGlow(0xFFDDDDDD);
		}
		flickerState = !flickerState;
	}

	override function destroy()
	{
		if (moveTween != null) moveTween.cancel();
		if (moveTimer != null) moveTimer.cancel();
		if (flickerTimer != null) flickerTimer.cancel();
		super.destroy();
	}
}
