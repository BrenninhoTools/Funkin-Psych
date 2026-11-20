package funkin.ui.options;

class PreferenceCheckbox extends FlxSprite
{
	public var currentValue(default, set):Bool = false;

	public function new(x:Float, y:Float, value:Bool = false)
	{
		super(x, y);
		frames = Paths.getSparrowAtlas('checkboxThingie');
		animation.addByPrefix('static', 'Check Box unselected', 24, false);
		animation.addByPrefix('checked', 'Check Box selecting animation', 24, false);
		antialiasing = Save.data.antialiasing;
		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
		currentValue = value;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (animation.curAnim == null) return;
		if (animation.curAnim.name == 'checked') offset.set(17, 70);
		else offset.set();
	}

	function set_currentValue(value:Bool):Bool
	{
		if (value != currentValue || animation.curAnim == null) animation.play(value ? 'checked' : 'static', true);
		return currentValue = value;
	}
}
