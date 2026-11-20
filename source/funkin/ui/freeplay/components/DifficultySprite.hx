package funkin.ui.freeplay.components;

class DifficultySprite extends FlxSprite
{
	public var difficultyId(default, null):String;

	public function new(difficulty:String)
	{
		super();
		difficultyId = difficulty;
		antialiasing = Save.data.antialiasing;

		var assetId:String = Paths.formatToSongPath(difficulty);
		while (!Paths.fileExists('images/freeplay/freeplay$assetId.png', IMAGE))
		{
			var parts:Array<String> = assetId.split('-');
			parts.pop();
			if (parts.length == 0)
			{
				assetId = null;
				break;
			}
			assetId = parts.join('-');
		}

		if (assetId == null)
		{
			var label:FlxText = new FlxText(0, 0, 0, difficulty.toUpperCase(), 64);
			label.setFormat(Paths.font('5by7_b.ttf'), 64, FlxColor.WHITE, LEFT, flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 4;
			label.drawFrame(true);
			loadGraphic(label.graphic);
			label.destroy();
			return;
		}

		if (Paths.fileExists('images/freeplay/freeplay$assetId.xml', TEXT))
		{
			frames = Paths.getSparrowAtlas('freeplay/freeplay$assetId');
			animation.addByPrefix('idle', 'idle0', 24, true);
			if (Save.data.flashing) animation.play('idle');
		}
		else loadGraphic(Paths.image('freeplay/freeplay$assetId'));
	}
}
