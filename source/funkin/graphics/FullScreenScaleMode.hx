package funkin.graphics;

import flixel.math.FlxRect;
import flixel.system.scaleModes.BaseScaleMode;

class FullScreenScaleMode extends BaseScaleMode
{
	public static var enabled(get, never):Bool;
	public static var offsetX(get, never):Float;
	public static var offsetY(get, never):Float;
	public static var safeArea(default, null):FlxRect = FlxRect.get(0, 0, 1280, 720);
	public static var safeInsets(default, null):Array<Float> = [0, 0, 0, 0];

	public var expandWidth:Bool = true;
	public var expandHeight:Bool = true;
	public var maxAspect:Float = 2.4;
	public var minAspect:Float = 4 / 3;

	public function new(expandWidth:Bool = true, expandHeight:Bool = true)
	{
		super();
		this.expandWidth = expandWidth;
		this.expandHeight = expandHeight;
	}

	override public function onMeasure(Width:Int, Height:Int):Void
	{
		var baseWidth:Int = FlxG.initialWidth;
		var baseHeight:Int = FlxG.initialHeight;
		var width:Int = baseWidth;
		var height:Int = baseHeight;

		if (Width > 0 && Height > 0)
		{
			var baseAspect:Float = baseWidth / baseHeight;
			var aspect:Float = Width / Height;
			if (aspect > baseAspect && expandWidth)
				width = even(baseHeight * Math.min(aspect, maxAspect));
			else if (aspect < baseAspect && expandHeight)
				height = even(baseWidth / Math.max(aspect, minAspect));
		}

		@:privateAccess
		{
			FlxG.width = width;
			FlxG.height = height;
		}

		updateGameSize(Width, Height);
		updateDeviceSize(Width, Height);
		updateScaleOffset();
		updateGamePosition();
		refreshSafeArea();
	}

	override function updateGameSize(Width:Int, Height:Int):Void
	{
		var ratio:Float = FlxG.width / FlxG.height;
		if (Width / Height > ratio)
			gameSize.set(Math.ceil(Height * ratio), Height);
		else
			gameSize.set(Width, Math.ceil(Width / ratio));
	}

	public static function refreshSafeArea():Void
	{
		var insets:Array<Float> = deviceInsets();
		var scaleX:Float = FlxG.scaleMode != null && FlxG.scaleMode.scale.x > 0 ? FlxG.scaleMode.scale.x : 1;
		var scaleY:Float = FlxG.scaleMode != null && FlxG.scaleMode.scale.y > 0 ? FlxG.scaleMode.scale.y : 1;
		safeInsets = [insets[0] / scaleX, insets[1] / scaleY, insets[2] / scaleX, insets[3] / scaleY];
		safeArea.set(safeInsets[0], safeInsets[1], FlxG.width - safeInsets[0] - safeInsets[2], FlxG.height - safeInsets[1] - safeInsets[3]);
	}

	static function deviceInsets():Array<Float>
	{
		#if android
		try
		{
			var raw:Dynamic = lime.system.JNI.createStaticMethod('org/psychengine/mobile/ScreenExtension', 'getSafeInsets', '()Ljava/lang/String;')();
			if (raw != null)
			{
				var parts:Array<String> = Std.string(raw).split(',');
				if (parts.length == 4)
				{
					var values:Array<Float> = [for (part in parts) Std.parseFloat(part)];
					var valid:Bool = true;
					for (value in values) if (Math.isNaN(value)) valid = false;
					if (valid)
					{
						var game:flixel.FlxGame = FlxG.game;
						if (game != null)
						{
							values[0] = Math.max(0, values[0] - game.x);
							values[1] = Math.max(0, values[1] - game.y);
							values[2] = Math.max(0, values[2] - (FlxG.stage.stageWidth - game.x - FlxG.scaleMode.gameSize.x));
							values[3] = Math.max(0, values[3] - (FlxG.stage.stageHeight - game.y - FlxG.scaleMode.gameSize.y));
						}
						return values;
					}
				}
			}
		}
		catch (e:Dynamic) {}
		#end
		return [0, 0, 0, 0];
	}

	public static function cover(sprite:FlxSprite, extra:Float = 1):FlxSprite
	{
		if (sprite == null || sprite.frameWidth <= 0 || sprite.frameHeight <= 0) return sprite;
		var scale:Float = Math.max(FlxG.width / sprite.frameWidth, FlxG.height / sprite.frameHeight) * extra;
		sprite.scale.set(scale, scale);
		sprite.updateHitbox();
		sprite.screenCenter();
		return sprite;
	}

	public static inline function centerX(x:Float):Float
		return x + offsetX;

	public static inline function centerY(y:Float):Float
		return y + offsetY;

	static inline function even(value:Float):Int
		return Std.int(Math.ceil(value / 2) * 2);

	static function get_enabled():Bool
		return Std.isOfType(FlxG.scaleMode, FullScreenScaleMode);

	static function get_offsetX():Float
		return (FlxG.width - FlxG.initialWidth) / 2;

	static function get_offsetY():Float
		return (FlxG.height - FlxG.initialHeight) / 2;
}
