package funkin.save;

import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import funkin.ui.title.TitleState;

class Save {
	public static var main(default, null):SaveFile = new SaveFile('funkin');
	public static var controls(default, null):SaveFile = new SaveFile('controls');
	static var initialized:Bool = false;

	public static var data:SaveVariables = {};
	public static var defaultData:SaveVariables = {};

	public static var keyBinds:Map<String, Array<FlxKey>> = [
		'note_up'		=> [W, UP],
		'note_left'		=> [A, LEFT],
		'note_down'		=> [S, DOWN],
		'note_right'	=> [D, RIGHT],
		
		'ui_up'			=> [W, UP],
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_right'		=> [D, RIGHT],
		
		'accept'		=> [SPACE, ENTER],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [R],
		
		'volume_mute'	=> [ZERO],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN],
		'debug_2'		=> [EIGHT]
	];
	public static var gamepadBinds:Map<String, Array<FlxGamepadInputID>> = [
		'note_up'		=> [DPAD_UP, Y],
		'note_left'		=> [DPAD_LEFT, X],
		'note_down'		=> [DPAD_DOWN, A],
		'note_right'	=> [DPAD_RIGHT, B],
		
		'ui_up'			=> [DPAD_UP, LEFT_STICK_DIGITAL_UP],
		'ui_left'		=> [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
		'ui_down'		=> [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
		'ui_right'		=> [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
		
		'accept'		=> [A, START],
		'back'			=> [B],
		'pause'			=> [START],
		'reset'			=> [BACK]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;
	public static var defaultButtons:Map<String, Array<FlxGamepadInputID>> = null;

	public static function resetKeys(controller:Null<Bool> = null)
	{
		if(controller != true)
			for (key in keyBinds.keys())
				if(defaultKeys.exists(key))
					keyBinds.set(key, defaultKeys.get(key).copy());

		if(controller != false)
			for (button in gamepadBinds.keys())
				if(defaultButtons.exists(button))
					gamepadBinds.set(button, defaultButtons.get(button).copy());
	}

	public static function clearInvalidKeys(key:String)
	{
		var keyBind:Array<FlxKey> = keyBinds.get(key);
		var gamepadBind:Array<FlxGamepadInputID> = gamepadBinds.get(key);
		while(keyBind != null && keyBind.contains(NONE)) keyBind.remove(NONE);
		while(gamepadBind != null && gamepadBind.contains(NONE)) gamepadBind.remove(NONE);
	}

	public static function loadDefaultKeys()
	{
		defaultKeys = keyBinds.copy();
		defaultButtons = gamepadBinds.copy();
	}

	public static function init()
	{
		if (initialized) return;
		initialized = true;

		if (!main.load())
		{
			var legacy:FlxSave = new FlxSave();
			legacy.bind('funkin', CoolUtil.getSavePath());
			if (!legacy.isEmpty()) main.importFrom(legacy.data);
			main.flush();
		}

		if (!controls.load())
		{
			var legacy:FlxSave = new FlxSave();
			legacy.bind('controls_v3', CoolUtil.getSavePath());
			if (!legacy.isEmpty()) controls.importFrom(legacy.data);
			controls.flush();
		}
	}

	public static inline function flush():Bool
		return main.flush();

	public static function saveSettings() {
		init();
		for (key in Reflect.fields(data))
			main.set(key, Reflect.field(data, key));

		#if ACHIEVEMENTS_ALLOWED Achievements.save(); #end
		main.flush();

		controls.set('keyboard', keyBinds);
		controls.set('gamepad', gamepadBinds);
		controls.flush();
		FlxG.log.add("Settings saved!");
	}

	public static function loadPrefs() {
		init();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		for (key in Reflect.fields(data))
			if (key != 'gameplaySettings' && main.has(key))
				Reflect.setField(data, key, main.get(key));

		#if mobile
		if (!main.has('mobileGpuCacheDefault'))
		{
			data.cacheOnGPU = true;
			main.set('mobileGpuCacheDefault', true);
			main.set('cacheOnGPU', true);
			main.flush();
		}
		#end
		
		if (!main.has('screenStyleVersion'))
		{
			data.screenStyle = 'Full';
			data.screenStyleVersion = 1;
		}
		if (!main.has('hapticsMode') && main.has('haptics'))
			data.hapticsMode = main.get('haptics') == false ? 'None' : 'All';
		if (!main.has('fpsStyle') && main.has('showFPS'))
			data.fpsStyle = main.get('showFPS') == false ? 'Disable' : 'Simple';
		if(Main.fpsVar != null)
			Main.fpsVar.style = data.fpsStyle;

		#if (!html5 && !switch)
		FlxG.autoPause = data.autoPause;

		if(!main.has('framerate')) {
			final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
			data.framerate = Std.int(FlxMath.bound(refreshRate, 60, 240));
		}
		#end

		FPSManager.apply();
		funkin.optimize.Optimizer.init();

		if(main.has('gameplaySettings'))
		{
			var savedMap:Map<String, Dynamic> = main.get('gameplaySettings');
			for (name => value in savedMap)
				data.gameplaySettings.set(name, value);
		}
		
		if(FlxG.save.data.volume != null)
			FlxG.sound.volume = FlxG.save.data.volume;
		if (FlxG.save.data.mute != null)
			FlxG.sound.muted = FlxG.save.data.mute;

		#if DISCORD_ALLOWED DiscordClient.check(); #end
		funkin.graphics.ScreenFit.apply();

		{
			if(controls.has('keyboard'))
			{
				var loadedControls:Map<String, Array<FlxKey>> = controls.get('keyboard');
				for (control => keys in loadedControls)
					if(keyBinds.exists(control)) keyBinds.set(control, keys);
			}
			if(controls.has('gamepad'))
			{
				var loadedControls:Map<String, Array<FlxGamepadInputID>> = controls.get('gamepad');
				for (control => keys in loadedControls)
					if(gamepadBinds.exists(control)) gamepadBinds.set(control, keys);
			}
			reloadVolumeKeys();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic = null, ?customDefaultValue:Bool = false):Dynamic
	{
		if(!customDefaultValue) defaultValue = defaultData.gameplaySettings.get(name);
		return (data.gameplaySettings.exists(name) ? data.gameplaySettings.get(name) : defaultValue);
	}

	public static function reloadVolumeKeys()
	{
		TitleState.muteKeys = keyBinds.get('volume_mute').copy();
		TitleState.volumeDownKeys = keyBinds.get('volume_down').copy();
		TitleState.volumeUpKeys = keyBinds.get('volume_up').copy();
		toggleVolumeKeys(true);
	}
	public static function toggleVolumeKeys(?turnOn:Bool = true)
	{
		final emptyArray = [];
		FlxG.sound.muteKeys = turnOn ? TitleState.muteKeys : emptyArray;
		FlxG.sound.volumeDownKeys = turnOn ? TitleState.volumeDownKeys : emptyArray;
		FlxG.sound.volumeUpKeys = turnOn ? TitleState.volumeUpKeys : emptyArray;
	}
}
