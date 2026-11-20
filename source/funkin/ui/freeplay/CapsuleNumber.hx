package funkin.ui.freeplay;

class CapsuleNumber extends FlxSprite
{
	static final NAMES:Array<String> = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];

	public var digit(default, set):Int = 0;

	public function new(x:Float, y:Float, big:Bool = false, initDigit:Int = 0)
	{
		super(x, y);
		frames = Paths.getSparrowAtlas(big ? 'freeplay/freeplayCapsule/bignumbers' : 'freeplay/freeplayCapsule/smallnumbers');
		for (name in NAMES) animation.addByPrefix(name, name, 24, false);
		antialiasing = Save.data.antialiasing;
		digit = initDigit;
	}

	function set_digit(value:Int):Int
	{
		value = FlxMath.maxInt(0, value) % 10;
		animation.play(NAMES[value], true, false, 0);
		centerOffsets(false);
		switch (value)
		{
			case 1:
				offset.x -= 4;
			case 3:
				offset.x -= 1;
			default:
		}
		return digit = value;
	}
}
