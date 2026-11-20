package funkin.ui.switchgame;

import funkin.data.ui.UIData;
import funkin.switchgame.SwitchGame;
import funkin.switchgame.SwitchGame.SwitchEngine;
import funkin.ui.text.Alphabet;

class SwitchEngineState extends MusicBeatState
{
	public static var returnState:Void->flixel.FlxState = null;

	var engines:Array<SwitchEngine> = [];
	var available:Array<Bool> = [];
	var items:FlxTypedGroup<Alphabet>;
	var bg:FlxSprite;
	var infoText:FlxText;
	var statusText:FlxText;
	var curSelected:Int = 0;
	var busy:Bool = false;
	var confirming:Bool = false;
	var colorTween:FlxTween;

	override function create()
	{
		persistentUpdate = true;
		engines = SwitchGame.load();
		available = [for (engine in engines) SwitchGame.isAvailable(engine)];

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		funkin.graphics.FullScreenScaleMode.cover(bg);
		bg.antialiasing = Save.data.antialiasing;
		bg.screenCenter();
		add(bg);

		items = new FlxTypedGroup<Alphabet>();
		add(items);
		for (num => engine in engines)
		{
			var item:Alphabet = new Alphabet(90, 320, engine.name, true);
			item.isMenuItem = true;
			item.targetY = num;
			item.snapToPosition();
			items.add(item);
		}

		var box:FlxSprite = new FlxSprite(0, FlxG.height - 120).makeGraphic(FlxG.width, 120, FlxColor.BLACK);
		box.alpha = 0.6;
		add(box);

		infoText = new FlxText(40, FlxG.height - 108, FlxG.width - 80, '', 22);
		infoText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		add(infoText);

		statusText = new FlxText(40, FlxG.height - 44, FlxG.width - 80, '', 18);
		statusText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		add(statusText);

		var header:FlxText = new FlxText(0, 24, FlxG.width, 'SWITCH ENGINE', 36);
		header.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(header);

		if (engines.length < 1)
		{
			infoText.text = 'No engines registered.\nAdd them to data/switchgame/engines.json';
			bg.color = 0xFF555555;
		}
		else changeSelection();

		#if mobile
		add(funkin.mobile.controls.MobileButton.back());
		#end
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (busy) return;

		if (engines.length > 0)
		{
			if (controls.UI_UP_P) changeSelection(-1);
			if (controls.UI_DOWN_P) changeSelection(1);
			if (FlxG.mouse.wheel != 0) changeSelection(-FlxG.mouse.wheel);

			var accept:Bool = controls.ACCEPT;
			#if mobile
			var tapped:Int = funkin.mobile.input.TouchInput.tappedRow([for (item in items.members) (item:flixel.FlxObject)]);
			if (tapped > -1)
			{
				if (tapped == curSelected) accept = true;
				else changeSelection(tapped - curSelected);
			}
			#end
			if (accept) choose();
		}

		if (controls.BACK)
		{
			if (confirming)
			{
				confirming = false;
				updateInfo();
				FlxG.sound.play(Paths.sound('cancelMenu'));
				return;
			}
			busy = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(returnState != null ? returnState() : new funkin.ui.mainmenu.MainMenuState());
			returnState = null;
		}
	}

	function choose()
	{
		var engine:SwitchEngine = engines[curSelected];
		if (!SwitchGame.supported(engine))
		{
			statusText.text = '${engine.name} has no launch info for ${SwitchGame.platform()}.';
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}
		if (!confirming)
		{
			confirming = true;
			statusText.text = 'Press ACCEPT again to close this game and open ${engine.name}.';
			FlxG.sound.play(Paths.sound('scrollMenu'));
			return;
		}

		confirming = false;
		busy = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		statusText.text = 'Opening ${engine.name}...';
		var transition:SwitchTransition = null;
		transition = SwitchTransition.playOut(engine.name, UIData.parseColor(engine.color, FlxColor.WHITE), function()
		{
			if (SwitchGame.switchTo(engine, true, 0.05)) return;
			statusText.text = 'Could not open ${engine.name}: ${SwitchGame.lastError}';
			FlxG.sound.play(Paths.sound('cancelMenu'));
			transition.fail(SwitchGame.lastError, () -> busy = false);
		});
	}

	override function destroy()
	{
		if (SwitchTransition.current != null && !busy) SwitchTransition.cancelCurrent();
		super.destroy();
	}

	function changeSelection(change:Int = 0)
	{
		if (engines.length < 1) return;
		confirming = false;
		if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, engines.length - 1);
		for (num => item in items.members)
		{
			item.targetY = num - curSelected;
			item.alpha = num == curSelected ? 1 : 0.6;
			if (!available[num]) item.alpha *= 0.6;
		}

		var color:FlxColor = UIData.parseColor(engines[curSelected].color, FlxColor.WHITE);
		if (colorTween != null) colorTween.cancel();
		colorTween = FlxTween.color(bg, 0.6, bg.color, color, {onComplete: (_) -> colorTween = null});
		updateInfo();
	}

	function updateInfo()
	{
		var engine:SwitchEngine = engines[curSelected];
		infoText.text = engine.description;
		if (!SwitchGame.supported(engine)) statusText.text = 'Not available on ${SwitchGame.platform()}';
		else statusText.text = available[curSelected] ? 'Installed  -  press ACCEPT to switch' : 'Not found  -  check data/switchgame/engines.json';
	}
}
