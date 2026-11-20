package funkin.ui.options;

import flixel.FlxObject;
import flixel.addons.display.FlxRuntimeShader;
import flixel.effects.FlxFlicker;
import funkin.data.stage.StageData;
import funkin.play.PlayState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.ui.transition.LoadingState;

class OptionsState extends MusicBeatState
{
	static inline var CAMERA_MARGIN:Int = 150;

	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	public static var reopenMobileOptions:Bool = false;

	static var curSelected:Int = 0;
	static var hsvSource:String = null;

	var options:Array<String> = [];
	var grpOptions:FlxTypedGroup<Alphabet>;
	var camFocusPoint:FlxObject;
	var busy:Bool = false;

	public static function createBackground():FlxSprite
	{
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = Save.data.antialiasing;
		if (Save.data.shaders)
		{
			if (hsvSource == null) hsvSource = Paths.getTextFromFile('shaders/hsv.frag');
			if (hsvSource != null)
			{
				try
				{
					var shader:FlxRuntimeShader = new FlxRuntimeShader(hsvSource);
					shader.setFloat('_hue', -0.6);
					shader.setFloat('_sat', 0.9);
					shader.setFloat('_val', 3.6);
					bg.shader = shader;
				}
				catch (e:Dynamic)
				{
					bg.color = 0xFFEA71FD;
				}
			}
			else bg.color = 0xFFEA71FD;
		}
		else bg.color = 0xFFEA71FD;
		bg.setGraphicSize(Std.int(FlxG.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		return bg;
	}

	function buildOptions()
	{
		options = ['PREFERENCES', 'GAMEPLAY', 'GRAPHICS', 'NOTE COLORS'];
		#if !mobile
		options.push('CONTROLS');
		options.push('LAG ADJUSTMENT');
		#end
		#if mobile
		options.push('MOBILE OPTIONS');
		#end
		#if TRANSLATIONS_ALLOWED
		options.push('LANGUAGE');
		#end
		options.push('SWITCH ENGINE');
		#if android
		if (funkin.mobile.storage.StorageUtil.isAppOwned()) options.push('OPEN DATA FOLDER');
		#end
		options.push('EXIT');
	}

	function openSelected(label:String)
	{
		switch (label)
		{
			case 'PREFERENCES':
				openSubState(new VisualsSettingsSubState());
			case 'GAMEPLAY':
				openSubState(new GameplaySettingsSubState());
			case 'GRAPHICS':
				openSubState(new GraphicsSettingsSubState());
			case 'NOTE COLORS':
				openSubState(new NotesColorSubState());
			case 'CONTROLS':
				openSubState(new ControlsSubState());
			case 'LAG ADJUSTMENT':
				MusicBeatState.switchState(new NoteOffsetState());
			case 'LANGUAGE':
				openSubState(new LanguageSubState());
			case 'SWITCH ENGINE':
				funkin.ui.switchgame.SwitchEngineState.returnState = () -> new OptionsState();
				MusicBeatState.switchState(new funkin.ui.switchgame.SwitchEngineState());
			case 'EXIT':
				exit();
			#if mobile
			case 'MOBILE OPTIONS':
				openSubState(new MobileSettingsSubState());
			case 'OPEN DATA FOLDER':
				funkin.mobile.storage.DataFolder.open();
			#end
		}
	}

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Options Menu', null);
		#end

		persistentUpdate = true;
		buildOptions();

		menuBG = createBackground();
		add(menuBG);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);
		for (num => option in options)
		{
			var item:Alphabet = new Alphabet(0, 100 + num * 100, Language.getPhrase('options_${option.toLowerCase().replace(' ', '_')}', option), true);
			item.screenCenter(X);
			grpOptions.add(item);
		}

		camFocusPoint = new FlxObject(0, 0, 140, 70);
		add(camFocusPoint);
		FlxG.camera.follow(camFocusPoint, null, 0.085);
		FlxG.camera.deadzone.set(0, CAMERA_MARGIN / 2, FlxG.camera.width, FlxG.camera.height - CAMERA_MARGIN + 40);
		FlxG.camera.minScrollY = -CAMERA_MARGIN / 2;

		curSelected = Std.int(FlxMath.bound(curSelected, 0, options.length - 1));
		changeSelection(0, false);
		FlxG.camera.snapToTarget();
		Save.saveSettings();

		#if mobile
		add(funkin.mobile.controls.MobileButton.back());
		#end

		super.create();

		#if mobile
		if (reopenMobileOptions)
		{
			reopenMobileOptions = false;
			var index:Int = options.indexOf('MOBILE OPTIONS');
			if (index > -1)
			{
				curSelected = index;
				changeSelection(0, false);
				openSelected('MOBILE OPTIONS');
			}
		}
		#end
	}

	override function openSubState(subState:flixel.FlxSubState)
	{
		FlxG.camera.follow(null);
		FlxG.camera.scroll.set();
		super.openSubState(subState);
	}

	override function closeSubState()
	{
		super.closeSubState();
		FlxG.camera.follow(camFocusPoint, null, 0.085);
		FlxG.camera.deadzone.set(0, CAMERA_MARGIN / 2, FlxG.camera.width, FlxG.camera.height - CAMERA_MARGIN + 40);
		FlxG.camera.snapToTarget();
		Save.saveSettings();
		busy = false;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Options Menu', null);
		#end
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8) FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);
		super.update(elapsed);
		if (busy || subState != null) return;

		var touchAccept:Bool = false;
		#if mobile
		var tapped:Int = funkin.mobile.input.TouchInput.tappedRow(cast grpOptions.members);
		funkin.mobile.input.TouchInput.consumeTap();
		if (tapped > -1)
		{
			if (tapped == curSelected) touchAccept = true;
			else changeSelection(tapped - curSelected);
		}
		#end

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);

		if (controls.BACK) exit();
		else if (controls.ACCEPT || touchAccept) accept();
	}

	function accept()
	{
		var label:String = options[curSelected];
		FunkinSound.playOnce('confirmMenu');
		funkin.util.HapticUtil.menuConfirm();
		if (label == 'EXIT' || label == 'LAG ADJUSTMENT' || label == 'SWITCH ENGINE')
		{
			busy = true;
			FlxFlicker.flicker(grpOptions.members[curSelected], 1, 0.06, true, false, function(_) openSelected(label));
			return;
		}
		openSelected(label);
	}

	function exit()
	{
		busy = true;
		FunkinSound.playOnce('cancelMenu');
		if (onPlayState)
		{
			StageData.loadDirectory(PlayState.SONG);
			LoadingState.loadAndSwitchState(new PlayState());
			FlxG.sound.music.volume = 0;
		}
		else MusicBeatState.switchState(new MainMenuState());
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		for (num => item in grpOptions.members) item.alpha = num == curSelected ? 1 : 0.6;
		camFocusPoint.y = grpOptions.members[curSelected].y;
		if (playSound)
		{
			FunkinSound.playOnce('scrollMenu');
			funkin.util.HapticUtil.menuScroll();
		}
	}

	override function destroy()
	{
		Save.loadPrefs();
		super.destroy();
	}
}
