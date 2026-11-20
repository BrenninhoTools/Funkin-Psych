package funkin.ui.freeplay.components;

import funkin.shaders.PureColor;

class DifficultySelector extends FlxSprite
{
	var whiteShader:PureColor;
	var pressTimer:FlxTimer;

	public function new(x:Float, y:Float, flipped:Bool, asset:String)
	{
		super(x, y);
		whiteShader = new PureColor(FlxColor.WHITE);
		whiteShader.colorSet = true;
		frames = Paths.getSparrowAtlas(asset);
		animation.addByPrefix('shine', 'arrow pointer loop', 24);
		animation.play('shine');
		antialiasing = Save.data.antialiasing;
		flipX = flipped;
	}

	public function press():Void
	{
		offset.y -= 5;
		scale.set(0.5, 0.5);
		shader = whiteShader;
		if (pressTimer != null) pressTimer.cancel();
		pressTimer = new FlxTimer().start(2 / 24, function(_)
		{
			scale.set(1, 1);
			shader = null;
			updateHitbox();
		});
	}

	override function destroy()
	{
		if (pressTimer != null) pressTimer.cancel();
		super.destroy();
	}
}
