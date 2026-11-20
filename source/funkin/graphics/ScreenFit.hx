package funkin.graphics;

import flixel.system.scaleModes.RatioScaleMode;

class ScreenFit
{
	public static inline final ORIGINAL:String = 'Original';
	public static inline final FULL:String = 'Full';
	public static final MODES:Array<String> = [ORIGINAL, FULL];

	static var listening:Bool = false;
	static var lastWidth:Int = 0;
	static var lastHeight:Int = 0;

	public static function apply():Void
	{
		if (FlxG.game == null) return;
		if (!listening)
		{
			listening = true;
			FlxG.signals.gameResized.add(function(_, _) resizeCameras());
			FlxG.cameras.cameraAdded.add(fitCamera);
			FlxG.signals.postStateSwitch.add(resizeCameras);
		}

		var full:Bool = Save.data.screenStyle != ORIGINAL;
		if (full && Std.isOfType(FlxG.scaleMode, FullScreenScaleMode)) return;
		if (!full && !Std.isOfType(FlxG.scaleMode, FullScreenScaleMode) && Std.isOfType(FlxG.scaleMode, RatioScaleMode)) return;

		if (lastWidth == 0) lastWidth = FlxG.width;
		if (lastHeight == 0) lastHeight = FlxG.height;
		FlxG.scaleMode = full ? new FullScreenScaleMode() : new RatioScaleMode();
		resizeCameras();
	}

	static function fitCamera(camera:FlxCamera):Void
	{
		if (camera == null) return;
		var matchesBase:Bool = camera.width == FlxG.initialWidth && camera.height == FlxG.initialHeight;
		var matchesLast:Bool = camera.width == lastWidth && camera.height == lastHeight;
		if ((matchesBase || matchesLast) && (camera.width != FlxG.width || camera.height != FlxG.height))
			camera.setSize(FlxG.width, FlxG.height);
	}

	static function resizeCameras():Void
	{
		if (lastWidth == 0) lastWidth = FlxG.initialWidth;
		if (lastHeight == 0) lastHeight = FlxG.initialHeight;
		if (lastWidth != FlxG.width || lastHeight != FlxG.height)
		{
			for (camera in FlxG.cameras.list)
				if (camera != null && camera.width == lastWidth && camera.height == lastHeight)
					camera.setSize(FlxG.width, FlxG.height);
		}
		for (camera in FlxG.cameras.list) fitCamera(camera);
		lastWidth = FlxG.width;
		lastHeight = FlxG.height;
	}
}
