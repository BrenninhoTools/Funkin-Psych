package funkin.ui.freeplay;

import flixel.FlxObject;

class LetterSort extends FlxSpriteGroup
{
	public static final FILTERS:Array<String> = ['#', 'fav', 'ALL', 'A-B', 'C-D', 'E-H', 'I-L', 'M-N', 'O-R', 'S', 'T', 'U-Z'];

	public var letters:Array<FreeplayLetter> = [];
	public var hitboxes:Array<FlxObject> = [];
	public var changeSelectionCallback:String->Void;

	var curSelection:Int = 2;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var separators:Array<FlxSprite> = [];

	public function new(x:Float, y:Float)
	{
		super(x, y);

		leftArrow = new FlxSprite(-20, 15).loadGraphic(Paths.image('freeplay/miniArrow'));
		leftArrow.flipX = true;
		add(leftArrow);
		rightArrow = new FlxSprite(380, 15).loadGraphic(Paths.image('freeplay/miniArrow'));
		add(rightArrow);

		for (i in 0...5)
		{
			var letter:FreeplayLetter = new FreeplayLetter(i * 80, -10, i, curSelection);
			add(letter);
			letters.push(letter);
			var hitbox:FlxObject = new FlxObject(0, 0, 50, 50);
			hitbox.active = false;
			hitboxes.push(hitbox);

			if (i != 2) letter.scale.set(0.8, 0.8);
			var darkness:Float = Math.max(Math.abs(i - 2) / 6, 0.01);
			letter.color = letter.color.getDarkened(darkness);

			if (i == 4) continue;
			var sep:FlxSprite = new FlxSprite((i * 80) + 60, 20).loadGraphic(Paths.image('freeplay/seperator'));
			sep.color = letter.color.getDarkened(darkness);
			add(sep);
			separators.push(sep);
		}

		for (member in members)
			if (member != null) member.antialiasing = Save.data.antialiasing;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		for (i => hitbox in hitboxes)
		{
			hitbox.x = letters[i].x;
			hitbox.y = letters[i].y + 10;
		}
	}

	public function changeSelection(diff:Int = 0, playSound:Bool = true):Void
	{
		doLetterChangeAnims(diff);
		var arrow:FlxSprite = diff < 0 ? leftArrow : rightArrow;
		arrow.offset.x = 3 * (diff > 0 ? 1 : -1);
		new FlxTimer().start(2 / 24, function(_) arrow.offset.x = 0);
		if (playSound && diff != 0) FunkinSound.playOnce('scrollMenu', 0.4);
	}

	function doLetterChangeAnims(diff:Int):Void
	{
		var positions:Array<Float> = [-10, -22, 2, 0];
		var mult:Float = diff > 0 ? 1 : -1;
		function frameSet(frame:Int, sprite:FlxSprite, value:Float)
			new FlxTimer().start(frame / 24, function(_) sprite.offset.x = value);

		for (sep in separators)
			for (i in 0...4) frameSet(i, sep, positions[i] * mult);

		for (index => letter in letters)
		{
			letter.offset.x = positions[0] * mult;
			new FlxTimer().start(1 / 24, function(_)
			{
				letter.offset.x = positions[1] * mult;
				if (index == 0) letter.visible = false;
			});
			new FlxTimer().start(2 / 24, function(_)
			{
				letter.offset.x = positions[2] * mult;
				if (index == 0) letter.visible = true;
			});
			frameSet(3, letter, index == 2 ? 0 : positions[3] * mult);
		}

		curSelection = FlxMath.wrap(curSelection + diff, 0, FILTERS.length - 1);
		for (letter in letters) letter.changeLetter(diff, curSelection);
		if (changeSelectionCallback != null) changeSelectionCallback(FILTERS[letters[2].curLetter]);
	}
}

class FreeplayLetter extends FreeplayAnimate
{
	public var curLetter:Int = 0;

	public function new(x:Float, y:Float, letterIndex:Int, curSelected:Int)
	{
		super(x, y, 'freeplay/sortedLetters', TOP_LEFT);
		curLetter = letterIndex;
		playLetter();
		if (curSelected != curLetter) anim.pause();
		anim.onComplete.add(function()
		{
			if (!anim.isPlaying) playLetter();
		});
	}

	function playLetter()
	{
		var name:String = StringTools.replace(LetterSort.FILTERS[curLetter], '-', '') + ' move';
		if (anim.symbolDictionary.exists(name)) anim.play(name, true);
	}

	public function changeLetter(diff:Int, curSelection:Int):Void
	{
		curLetter = FlxMath.wrap(curLetter + diff, 0, LetterSort.FILTERS.length - 1);
		playLetter();
		if (curSelection != curLetter) anim.pause();
	}
}
