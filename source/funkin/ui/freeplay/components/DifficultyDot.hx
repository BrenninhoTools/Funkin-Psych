package funkin.ui.freeplay.components;

enum DotType
{
	NORMAL;
	ERECT;
	INACTIVE;
}

enum DotState
{
	DESELECTING;
	DESELECTED;
	SELECTED;
}

class DifficultyDot extends FlxSprite
{
	static final NORMAL_COLORS:Array<FlxColor> = [0xFF484848, 0xFFFAFAFA];
	static final NIGHT_COLORS:Array<FlxColor> = [0xFF34296A, 0xFFC28AFF];

	public var difficultyId(default, null):String;
	public var type(default, null):DotType = NORMAL;

	var colorTween:FlxTween;
	var fadeTween:FlxTween;

	public function new(id:String)
	{
		super();
		difficultyId = id;
		loadGraphic(Paths.image('freeplay/seperator'));
		antialiasing = Save.data.antialiasing;
		alpha = 0;
	}

	public function updateState(newType:DotType, newState:DotState):Void
	{
		type = newType;
		if (colorTween != null) colorTween.cancel();
		var colors:Array<FlxColor> = type == ERECT ? NIGHT_COLORS : NORMAL_COLORS;
		var faded:Bool = fadeTween == null || fadeTween.finished;
		switch (type)
		{
			case INACTIVE:
				color = 0xFF121212;
				if (faded) alpha = 0.33;
			default:
				if (faded) alpha = 1;
				switch (newState)
				{
					case SELECTED:
						color = colors[1];
					case DESELECTING:
						colorTween = FlxTween.color(this, 0.5, colors[1], colors[0], {ease: FlxEase.quartOut});
					case DESELECTED:
						color = colors[0];
				}
		}
	}

	public function fadeIn():Void
	{
		alpha = 0;
		if (fadeTween != null) fadeTween.cancel();
		fadeTween = FlxTween.tween(this, {alpha: type == INACTIVE ? 0.33 : 1}, 0.5, {ease: FlxEase.quartOut});
	}

	public function fadeOut():Void
	{
		if (fadeTween != null) fadeTween.cancel();
		fadeTween = FlxTween.tween(this, {alpha: 0}, 0.25, {ease: FlxEase.quartOut});
	}
}
