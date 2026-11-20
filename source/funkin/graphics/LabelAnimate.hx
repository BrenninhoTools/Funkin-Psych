package funkin.graphics;

class LabelAnimate extends FlxAnimate
{
	public var currentLabel(get, never):String;
	public var onLabelFinish:String->Void = null;
	public var finished(get, never):Bool;

	public function new(x:Float = 0, y:Float = 0, ?folder:String, applyStageMatrix:Bool = true)
	{
		super(x, y);
		antialiasing = Save.data.antialiasing;
		onAnimationComplete.add(function(name:String)
		{
			if (onLabelFinish != null) onLabelFinish(name);
		});
		if (folder != null) loadFolder(folder, applyStageMatrix);
	}

	public function loadFolder(folder:String, applyStageMatrix:Bool = true):Bool
	{
		try
		{
			Paths.loadAnimateAtlas(this, folder);
		}
		catch (e:Dynamic)
		{
			return false;
		}
		if (anim == null || anim.stageInstance == null) return false;
		setupLabels(applyStageMatrix);
		return true;
	}

	public inline function hasLabel(name:String):Bool
		return frameLabels.contains(name);

	public function playLabel(name:String, force:Bool = true, loop:Bool = false):Bool
	{
		if (!hasLabel(name)) return false;
		return playAnimation(name, force, false, loop);
	}

	inline function get_currentLabel():String
		return animationName;

	inline function get_finished():Bool
		return isAnimationFinished();
}
