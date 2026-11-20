package funkin.ui.mainmenu;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import funkin.play.PlayState;
import funkin.ui.credits.CreditsState;
import funkin.ui.debug.MasterEditorMenu;
import funkin.ui.freeplay.FreeplayState;
import funkin.ui.options.OptionsState;
import funkin.ui.story.StoryMenuState;
import funkin.ui.title.TitleState;
import lime.app.Application;
#if ACHIEVEMENTS_ALLOWED
import funkin.ui.achievements.AchievementsMenuState;
#end
#if MODS_ALLOWED
import funkin.ui.mods.ModsMenuState;
#end

typedef MainMenuEntry =
{
	id:String,
	atlas:String,
	callback:Void->Void,
	?instant:Bool
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4';

	static inline var SPACING:Float = 160;
	static var rememberedSelectedIndex:Int = 0;
	static var showOutdatedWarning:Bool = true;

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var menuItems:FlxTypedGroup<FlxSprite>;
	var entries:Array<MainMenuEntry> = [];
	var curSelected:Int = 0;
	var busy:Bool = false;

	#if mobile
	var editorsButton:funkin.mobile.controls.ImageButton;
	#end

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('In the Menus', null);
		#end

		if (FlxG.sound.music == null || !FlxG.sound.music.playing) FunkinSound.playMusic('freakyMenu');
		persistentUpdate = persistentDraw = true;

		bg = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		bg.scrollFactor.set(#if mobile 0.17 #else 0 #end, 0.17);
		bg.setGraphicSize(Std.int(FlxG.width * 1.2));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = Save.data.antialiasing;
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite().loadGraphic(Paths.image('menuBGMagenta'));
		magenta.scrollFactor.copyFrom(bg.scrollFactor);
		magenta.setGraphicSize(Std.int(bg.width));
		magenta.updateHitbox();
		magenta.setPosition(bg.x, bg.y);
		magenta.antialiasing = Save.data.antialiasing;
		magenta.visible = false;
		if (Save.data.flashing) add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		addEntry('storymode', 'mainmenu/storymode', () -> exitTo(() -> new StoryMenuState()));
		addEntry('freeplay', 'mainmenu/freeplay', function()
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			rememberedSelectedIndex = curSelected;
			MusicBeatState.switchState(new FreeplayState());
		});
		#if MODS_ALLOWED
		addEntry('mods', 'mainmenu/menu_mods', () -> exitTo(() -> new ModsMenuState()));
		#end
		#if ACHIEVEMENTS_ALLOWED
		addEntry('achievements', 'mainmenu/menu_achievements', () -> exitTo(() -> new AchievementsMenuState()));
		#end
		addEntry('merch', 'mainmenu/merch', function()
		{
			CoolUtil.browserLoad('https://needlejuicerecords.com/pages/friday-night-funkin');
			busy = false;
		}, true);
		addEntry('options', 'mainmenu/options', function()
		{
			OptionsState.onPlayState = false;
			if (PlayState.SONG != null)
			{
				PlayState.SONG.arrowSkin = null;
				PlayState.SONG.splashSkin = null;
				PlayState.stageUI = 'normal';
			}
			exitTo(() -> new OptionsState());
		});
		addEntry('credits', 'mainmenu/credits', () -> exitTo(() -> new CreditsState()));

		var top:Float = (FlxG.height - (SPACING * (menuItems.length - 1))) / 2;
		for (index => item in menuItems.members)
		{
			item.x = FlxG.width / 2;
			item.y = top + SPACING * index;
			item.scrollFactor.set(#if mobile 0.4 #else 0 #end, 0.4);
		}

		var versionText:FlxText = new FlxText(5, FlxG.height - 38, 0, 'Funkin\' Psych v$psychEngineVersion\nFriday Night Funkin\' v${Application.current.meta.get('version')}', 12);
		versionText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, flixel.text.FlxText.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionText.scrollFactor.set();
		add(versionText);

		curSelected = Std.int(FlxMath.bound(rememberedSelectedIndex, 0, menuItems.length - 1));
		selectItem(curSelected, false);
		FlxG.camera.follow(camFollow, null, 0.06);
		FlxG.camera.snapToTarget();

		#if ACHIEVEMENTS_ALLOWED
		var date:Date = Date.now();
		if (date.getDay() == 5 && date.getHours() >= 18) Achievements.unlock('friday_night_play');
		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if mobile
		add(funkin.mobile.controls.MobileButton.back(null, true));
		editorsButton = new funkin.mobile.controls.ImageButton(16, 50, 'editorButton', 0.6);
		add(editorsButton);
		#end

		super.create();

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && Save.data.checkForUpdates && funkin.ui.title.OutdatedSubState.updateVersion != psychEngineVersion)
		{
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new funkin.ui.title.OutdatedSubState());
		}
		#end
	}

	function addEntry(id:String, atlas:String, callback:Void->Void, instant:Bool = false)
	{
		var item:FlxSprite = new FlxSprite();
		item.frames = Paths.getSparrowAtlas(atlas);
		item.animation.addByPrefix('idle', '$id idle', 24);
		item.animation.addByPrefix('selected', '$id selected', 24);
		item.antialiasing = Save.data.antialiasing;
		item.ID = menuItems.length;
		menuItems.add(item);
		entries.push({id: id, atlas: atlas, callback: callback, instant: instant});
		changeAnim(item, 'idle');
	}

	function changeAnim(item:FlxSprite, name:String)
	{
		item.animation.play(name);
		item.updateHitbox();
		item.centerOrigin();
		item.offset.copyFrom(item.origin);
	}

	function selectItem(index:Int, playSound:Bool = true)
	{
		changeAnim(menuItems.members[curSelected], 'idle');
		curSelected = FlxMath.wrap(index, 0, menuItems.length - 1);
		var item:FlxSprite = menuItems.members[curSelected];
		changeAnim(item, 'selected');
		camFollow.setPosition(item.getGraphicMidpoint().x, item.getGraphicMidpoint().y);
		if (playSound) FunkinSound.playOnce('scrollMenu');
	}

	function accept()
	{
		var entry:MainMenuEntry = entries[curSelected];
		var item:FlxSprite = menuItems.members[curSelected];
		busy = true;
		FunkinSound.playOnce('confirmMenu');
		if (entry.instant)
		{
			entry.callback();
			return;
		}
		if (Save.data.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false, true);
		FlxFlicker.flicker(item, 1, 0.06, true, false, function(_) entry.callback());
	}

	function exitTo(factory:Void->flixel.FlxState)
	{
		rememberedSelectedIndex = curSelected;
		var duration:Float = 0.4;
		for (item in menuItems.members)
		{
			if (item.ID != curSelected) FlxTween.tween(item, {alpha: 0}, duration, {ease: FlxEase.quadOut});
			else item.visible = false;
		}
		new FlxTimer().start(duration, function(_) MusicBeatState.switchState(factory()));
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8) FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!busy && subState == null) handleInputs();
		super.update(elapsed);
	}

	function handleInputs()
	{
		if (controls.UI_UP_P) selectItem(curSelected - 1);
		if (controls.UI_DOWN_P) selectItem(curSelected + 1);
		if (FlxG.mouse.wheel != 0) selectItem(curSelected - FlxG.mouse.wheel);

		#if !mobile
		if (FlxG.mouse.justMoved || FlxG.mouse.justPressed)
		{
			FlxG.mouse.visible = true;
			for (item in menuItems.members)
			{
				if (!FlxG.mouse.overlaps(item)) continue;
				if (item.ID != curSelected) selectItem(item.ID);
				else if (FlxG.mouse.justPressed)
				{
					accept();
					return;
				}
				break;
			}
		}
		#end

		#if mobile
		if (funkin.mobile.input.TouchInput.justTapped())
		{
			for (item in menuItems.members)
			{
				if (!funkin.mobile.input.TouchInput.tappedOn(item)) continue;
				funkin.mobile.input.TouchInput.consumeTap();
				if (item.ID == curSelected) accept();
				else selectItem(item.ID);
				return;
			}
		}
		if (editorsButton.justTapped)
		{
			busy = true;
			MusicBeatState.switchState(new MasterEditorMenu());
			return;
		}
		#end

		if (FlxG.keys.justPressed.TAB)
		{
			busy = true;
			MusicBeatState.switchState(new funkin.ui.switchgame.SwitchEngineState());
			return;
		}

		#if desktop
		if (controls.justPressed('debug_1'))
		{
			busy = true;
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
			return;
		}
		#end

		if (controls.BACK)
		{
			busy = true;
			FlxG.mouse.visible = false;
			FunkinSound.playOnce('cancelMenu');
			MusicBeatState.switchState(new TitleState());
		}
		else if (controls.ACCEPT) accept();
	}

	override function closeSubState()
	{
		magenta.visible = false;
		busy = false;
		super.closeSubState();
	}
}
