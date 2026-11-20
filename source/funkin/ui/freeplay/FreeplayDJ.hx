package funkin.ui.freeplay;

import flixel.util.FlxSignal;
import haxe.Json;

enum FreeplayDJState
{
	Intro;
	Idle;
	IdleEasterEgg;
	Confirm;
}

class FreeplayDJ extends FlxAnimate
{
	public static inline var IDLE_EGG_PERIOD:Float = 60.0;

	public var onIntroDone:FlxSignal = new FlxSignal();
	public var texts(default, null):Array<String> = [];
	public var loaded(default, null):Bool = false;

	var currentState:FreeplayDJState = Intro;
	var labels:Map<String, String> = [];
	var available:Map<String, Bool> = [];
	var currentAnim:String = null;
	var timeIdling:Float = 0;
	var seenIdleEasterEgg:Bool = false;

	public static function loadData(character:String):Dynamic
	{
		var raw:String = Paths.getTextFromFile('data/ui/freeplay/dj-$character.json');
		if (raw == null) return null;
		try
		{
			return Json.parse(raw);
		}
		catch (e:Dynamic) {}
		return null;
	}

	public function new(offsetX:Float, data:Dynamic)
	{
		super();
		if (data == null) return;

		texts = [for (i in 1...4) Reflect.hasField(data, 'text$i') ? Std.string(Reflect.field(data, 'text$i')) : ''];
		var animatePosition:Bool = data.useAnimatePosition == true;
		setPosition(animatePosition ? offsetX : offsetX + 640, animatePosition ? 0 : 366);

		try
		{
			Paths.loadAnimateAtlas(this, Std.string(data.assetPath));
		}
		catch (e:Dynamic)
		{
			return;
		}

		var animations:Array<Dynamic> = data.animations != null ? data.animations : [];
		for (entry in animations)
		{
			var name:String = Std.string(entry.name);
			var prefix:String = Std.string(entry.prefix);
			labels.set(name, prefix);
			try
			{
				if (anim.getFrameLabel(prefix) == null) continue;
				anim.addByFrameLabel(name, prefix, 24, false);
				available.set(name, true);
			}
			catch (e:Dynamic) {}
		}

		loaded = available.exists('intro') || available.exists('idle');
		antialiasing = Save.data.antialiasing;
		anim.onComplete.add(onFinishAnim);
		if (!available.exists('intro')) currentState = Idle;
		play(currentState == Intro ? 'intro' : 'idle');
	}

	function play(name:String, force:Bool = true)
	{
		if (!available.exists(name)) return;
		currentAnim = name;
		anim.play(name, force);
	}

	function onFinishAnim():Void
	{
		if (anim.isPlaying) return;
		switch (currentState)
		{
			case Intro:
				currentState = Idle;
				onIntroDone.dispatch();
				play('idle');
			case Idle:
				if (timeIdling >= IDLE_EGG_PERIOD && !seenIdleEasterEgg && available.exists('idleEasterEgg'))
				{
					currentState = IdleEasterEgg;
					seenIdleEasterEgg = true;
					play('idleEasterEgg');
				}
				else play('idle');
			case IdleEasterEgg:
				currentState = Idle;
				timeIdling = 0;
				play('idle');
			case Confirm:
		}
	}

	public function skipIntro()
	{
		if (currentState != Intro) return;
		currentState = Idle;
		onIntroDone.dispatch();
		play('idle');
	}

	override function update(elapsed:Float):Void
	{
		if (currentState == Idle) timeIdling += elapsed;
		super.update(elapsed);
	}

	public function onPlayerAction():Void
	{
		timeIdling = 0;
		seenIdleEasterEgg = false;
		if (currentState == IdleEasterEgg)
		{
			currentState = Idle;
			play('idle');
		}
	}

	public function onConfirm():Void
	{
		currentState = Confirm;
		play('confirm');
	}

	public function getMusicPreviewMult():Float
		return currentState == IdleEasterEgg ? 0.3 : 1;

	override function destroy()
	{
		onIntroDone.removeAll();
		super.destroy();
	}
}
