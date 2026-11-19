package funkin.play.stages.modules;

import funkin.play.cutscenes.DialogueBox;
import openfl.utils.Assets as OpenFlAssets;

class SchoolDialogue extends BaseStage
{
	var options:Dynamic;
	var doof:DialogueBox = null;

	override function create()
	{
		options = StageModules.consumeOptions();
		if (!isStoryMode || seenCutscene) return;
		if (options.songs != null && !(cast options.songs:Array<Dynamic>).contains(songName)) return;
		initDoof();
		setStartCallback(options.intro == 'evil' ? evilIntro : fadeIntro);
	}

	function fileExists(file:String):Bool
	{
		#if MODS_ALLOWED
		return FileSystem.exists(file);
		#else
		return OpenFlAssets.exists(file);
		#end
	}

	function initDoof()
	{
		var file:String = Paths.txt('songs/$songName/${songName}Dialogue_${Save.data.language}');
		if (!fileExists(file)) file = Paths.txt('songs/$songName/${songName}Dialogue');
		if (!fileExists(file)) return;

		doof = new DialogueBox(false, CoolUtil.coolTextFile(file));
		doof.cameras = [camHUD];
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = PlayState.instance.startNextDialogue;
		doof.skipDialogueThing = PlayState.instance.skipDialogue;
	}

	function fadeIntro()
	{
		inCutscene = true;
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		var blackSongs:Array<Dynamic> = options.blackSongs != null ? options.blackSongs : ['senpai'];
		if (blackSongs.contains(songName)) add(black);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;
			if (black.alpha > 0)
			{
				tmr.reset(0.3);
				return;
			}
			if (doof != null) add(doof);
			else startCountdown();
			remove(black);
			black.destroy();
		});
	}

	function evilIntro()
	{
		if (doof == null)
		{
			startCountdown();
			return;
		}

		inCutscene = true;
		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();
		add(red);

		var senpai:FlxSprite = new FlxSprite();
		senpai.frames = Paths.getSparrowAtlas(options.image != null ? Std.string(options.image) : 'weeb/senpaiCrazy');
		senpai.animation.addByPrefix('idle', options.prefix != null ? Std.string(options.prefix) : 'Senpai Pre Explosion', 24, false);
		senpai.setGraphicSize(Std.int(senpai.width * 6));
		senpai.scrollFactor.set();
		senpai.updateHitbox();
		senpai.screenCenter();
		senpai.x += 300;
		camHUD.visible = false;

		new FlxTimer().start(2.1, function(_)
		{
			add(senpai);
			senpai.alpha = 0;
			new FlxTimer().start(0.3, function(swagTimer:FlxTimer)
			{
				senpai.alpha += 0.15;
				if (senpai.alpha < 1)
				{
					swagTimer.reset();
					return;
				}
				senpai.animation.play('idle');
				FlxG.sound.play(Paths.sound(options.sound != null ? Std.string(options.sound) : 'Senpai_Dies'), 1, false, null, true, function()
				{
					remove(senpai);
					senpai.destroy();
					remove(red);
					red.destroy();
					FlxG.camera.fade(FlxColor.WHITE, 0.01, true, function()
					{
						add(doof);
						camHUD.visible = true;
					}, true);
				});
				new FlxTimer().start(3.2, (_) -> FlxG.camera.fade(FlxColor.WHITE, 1.6, false));
			});
		});
	}
}
