package funkin.ui.freeplay;

class PixelatedIcon extends FlxSprite
{
	public var char(default, null):String = '';

	public function new(x:Float, y:Float)
	{
		super(x, y);
		makeGraphic(32, 32, 0x00000000);
		antialiasing = false;
		active = false;
		animation.onFinish.add(function(anim:String)
		{
			if (anim == 'confirm' && animation.exists('confirm-hold')) animation.play('confirm-hold');
		});
	}

	static final ALIASES:Map<String, String> = [
		'parents' => 'parents-christmas',
		'mom-dad' => 'parents-christmas',
		'dad-mom' => 'parents-christmas',
		'monster-christmas' => 'monster',
		'bf-christmas' => 'bf',
		'gf-christmas' => 'gf'
	];

	static function resolveAlias(name:String):String
	{
		if (name == null) return '';
		var key:String = name.toLowerCase();
		return ALIASES.exists(key) ? ALIASES.get(key) : key;
	}

	public function setCharacter(name:String):Void
	{
		if (char == name) return;

		var parts:Array<String> = resolveAlias(name).split('-');
		var current:String = '';
		var found:String = null;
		for (i in 0...parts.length)
		{
			current += parts[i];
			if (Paths.fileExists('images/freeplay/icons/${current}pixel.png', IMAGE)) found = current;
			if (i < parts.length - 1) current += '-';
		}
		if (found == null && Paths.fileExists('images/freeplay/icons/${parts[0]}pixel.png', IMAGE)) found = parts[0];

		if (found == null)
		{
			visible = false;
			char = name;
			return;
		}

		visible = true;
		char = name;
		var key:String = 'freeplay/icons/${found}pixel';
		var animated:Bool = Paths.fileExists('images/$key.xml', TEXT);
		if (animated) frames = Paths.getSparrowAtlas(key);
		else loadGraphic(Paths.image(key));

		antialiasing = false;
		scale.set(2, 2);
		origin.x = switch (found)
		{
			case 'parents-christmas': 140;
			case 'sserafim-kazuha': 195;
			default: 100;
		}

		active = animated;
		if (animated)
		{
			animation.addByPrefix('idle', 'idle0', 10, true);
			animation.addByPrefix('confirm', 'confirm0', 10, false);
			animation.addByPrefix('confirm-hold', 'confirm-hold0', 10, true);
			animation.play('idle');
		}
	}

	public function confirm()
	{
		if (visible && animation.exists('confirm')) animation.play('confirm');
	}
}
