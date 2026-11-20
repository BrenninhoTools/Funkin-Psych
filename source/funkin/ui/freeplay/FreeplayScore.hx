package funkin.ui.freeplay;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class FreeplayScore extends FlxTypedSpriteGroup<ScoreNum>
{
	public var score(default, set):Int = 0;

	public function new(x:Float, y:Float, digitCount:Int, numbersAsset:String)
	{
		super(0, y);
		for (i in 0...digitCount) add(new ScoreNum(x + (45 * i), y, numbersAsset));
		score = 0;
	}

	function set_score(value:Int):Int
	{
		score = value;
		if (group == null || group.members == null) return value;
		var number:Int = Std.int(Math.min(Math.max(0, value), Math.pow(10, group.members.length) - 1));
		var index:Int = group.members.length - 1;
		while (index >= 0)
		{
			group.members[index].digit = number % 10;
			number = Math.floor(number / 10);
			index--;
		}
		return value;
	}
}

class ScoreNum extends FlxSprite
{
	static final NAMES:Array<String> = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];

	public var digit(default, set):Int = -1;

	public function new(x:Float, y:Float, numbersAsset:String)
	{
		super(x, y);
		frames = Paths.getSparrowAtlas(numbersAsset);
		for (name in NAMES) animation.addByPrefix(name, '$name DIGITAL', 24, false);
		antialiasing = Save.data.antialiasing;
		digit = 0;
		setGraphicSize(Std.int(width * 0.4));
		updateHitbox();
	}

	function set_digit(value:Int):Int
	{
		if (value < 0 || value > 9) value = 0;
		if (digit == value) return value;
		digit = value;
		animation.play(NAMES[value], true, false, 0);
		updateHitbox();
		switch (value)
		{
			case 1:
				offset.x -= 15;
			case 4 | 5 | 7 | 9:
			default:
				centerOffsets(false);
		}
		return value;
	}
}
