package funkin.ui.freeplay;

class FreeplayFlames extends FlxSpriteGroup
{
	public var flameCount(default, set):Int = 0;

	var flameX:Float;
	var flameY:Float;
	var flameSpreadX:Float = 29;
	var flameSpreadY:Float = 6;
	var flameTimer:Float = 0.25;
	var timers:Array<FlxTimer> = [];

	public function new(baseX:Float, baseY:Float)
	{
		super();
		flameX = baseX;
		flameY = baseY;
		for (i in 0...5)
		{
			var flame:FlxSprite = new FlxSprite(flameX + (flameSpreadX * i), flameY + (flameSpreadY * i));
			flame.frames = Paths.getSparrowAtlas('freeplay/freeplayFlame');
			flame.animation.addByPrefix('flame', 'fire loop full instance 1', FlxG.random.int(23, 25), false);
			flame.animation.play('flame');
			flame.animation.onFinish.add(function(_) flame.animation.play('flame', true, false, 2));
			flame.antialiasing = Save.data.antialiasing;
			flame.visible = false;
			add(flame);
		}
	}

	function set_flameCount(value:Int):Int
	{
		for (timer in timers) timer.cancel();
		timers = [];
		flameCount = value;

		var visibleCount:Int = 0;
		for (i in 0...members.length)
		{
			var flame:FlxSprite = members[i];
			if (flame == null) continue;
			if (i >= flameCount)
			{
				flame.visible = false;
				continue;
			}
			if (flame.visible) continue;
			timers.push(new FlxTimer().start(flameTimer * visibleCount, function(_)
			{
				if (i >= flameCount) return;
				flame.animation.play('flame', true);
				flame.visible = true;
			}));
			visibleCount++;
		}
		return value;
	}

	override function destroy()
	{
		for (timer in timers) timer.cancel();
		timers = [];
		super.destroy();
	}
}
