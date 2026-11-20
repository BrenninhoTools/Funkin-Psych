package funkin.graphics;

class LabelAnimate extends FlxAnimate
{
	public var currentLabel(default, null):String = null;
	public var onLabelFinish:String->Void = null;

	var labels:Map<String, Bool> = [];
	var loops:Map<String, Bool> = [];
	var stageX:Float = 0;
	var stageY:Float = 0;

	public function new(x:Float = 0, y:Float = 0, ?folder:String, applyStageMatrix:Bool = true)
	{
		super(x, y);
		antialiasing = Save.data.antialiasing;
		anim.onComplete.add(onComplete);
		if (folder != null) loadFolder(folder, applyStageMatrix);
	}

	public function loadFolder(folder:String, applyStageMatrix:Bool = true):Bool
	{
		labels.clear();
		loops.clear();
		currentLabel = null;
		try
		{
			Paths.loadAnimateAtlas(this, folder);
		}
		catch (e:Dynamic)
		{
			return false;
		}
		if (anim == null || anim.stageInstance == null) return false;

		stageX = stageY = 0;
		if (applyStageMatrix && anim.stageInstance.matrix != null)
		{
			stageX = anim.stageInstance.matrix.tx;
			stageY = anim.stageInstance.matrix.ty;
		}

		try
		{
			for (frame in anim.getFrameLabels())
			{
				if (frame == null || frame.name == null || labels.exists(frame.name)) continue;
				anim.addByFrameLabel(frame.name, frame.name, 24, false, stageX, stageY);
				labels.set(frame.name, true);
			}
		}
		catch (e:Dynamic) {}
		return true;
	}

	public inline function hasLabel(name:String):Bool
		return labels.exists(name);

	public function playLabel(name:String, force:Bool = true, loop:Bool = false):Bool
	{
		if (!labels.exists(name)) return false;
		currentLabel = name;
		loops.set(name, loop);
		anim.play(name, force);
		return true;
	}

	public function playTimeline(loop:Bool = true)
	{
		currentLabel = '';
		loops.set('', loop);
		anim.play('', true);
	}

	public var finished(get, never):Bool;

	function get_finished():Bool
		return anim == null || !anim.isPlaying;

	function onComplete()
	{
		if (anim.isPlaying && currentLabel != '') return;
		var name:String = currentLabel;
		if (name != null && loops.get(name) == true)
		{
			if (name == '') anim.play('', true);
			else anim.play(name, true);
			return;
		}
		if (onLabelFinish != null && name != null) onLabelFinish(name);
	}
}
