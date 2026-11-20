package funkin.ui.freeplay;

class DifficultyStars extends FlxSpriteGroup
{
	public var difficulty(default, set):Int = 1;
	public var stars:FlxAnimate;
	public var flames:FreeplayFlames;

	var curDifficulty(default, set):Int = 0;

	public function new(x:Float, y:Float, flameX:Float)
	{
		super(x, y);
		flames = new FreeplayFlames(flameX - x, 91 - y);
		stars = new FlxAnimate();
		Paths.loadAnimateAtlas(stars, 'freeplay/freeplayStars');
		stars.antialiasing = Save.data.antialiasing;
		stars.anim.play('diff stars', true);
		add(flames);
		add(stars);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (curDifficulty < 15 && stars.anim.curFrame >= (curDifficulty + 1) * 100)
			stars.anim.play('diff stars', true, false, curDifficulty * 100);
	}

	function set_difficulty(value:Int):Int
	{
		if (value <= 0)
		{
			difficulty = 0;
			curDifficulty = 15;
		}
		else
		{
			difficulty = Std.int(Math.min(value, 15));
			curDifficulty = difficulty - 1;
		}
		flameCheck();
		return difficulty;
	}

	public function flameCheck():Void
		flames.flameCount = difficulty > 10 ? difficulty - 10 : 0;

	function set_curDifficulty(value:Int):Int
	{
		curDifficulty = value;
		if (stars == null) return value;
		if (curDifficulty == 15)
		{
			stars.anim.play('diff stars', true, false, 1500);
			stars.anim.pause();
		}
		else stars.anim.play('diff stars', true, false, curDifficulty * 100);
		return value;
	}
}
