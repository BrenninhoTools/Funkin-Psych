package;

import funkin.util.debug.FPSCounter;

import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import funkin.ui.title.TitleState;


#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import funkin.backend.ALSoftConfig; // Just to make sure DCE doesn't remove this, since it's not directly referenced anywhere else.
#end

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end

import funkin.backend.Highscore;
import funkin.backend.ClientPrefs;
import funkin.backend.Controls;
import funkin.backend.CoolUtil;
import funkin.modding.Mods;
import funkin.play.PlayState;
import flixel.FlxG;
import flixel.util.FlxColor;

#if DISCORD_ALLOWED
import funkin.api.discord.Discord;
#end

#if ACHIEVEMENTS_ALLOWED
import funkin.backend.Achievements;
#end

#if LUA_ALLOWED
import llua.Lua;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

// NATIVE API STUFF, YOU CAN IGNORE THIS AND SCROLL //
#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

// // // // // // // // //
class Main extends Sprite
{
	public static final game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: TitleState, // initial game state
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:FPSCounter;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		#if (cpp && windows)
		funkin.backend.Native.fixScaling();
		#end

		// Credits to MAJigsaw77 (he's the og author for this code)
		#if mobile
		funkin.mobile.storage.StorageUtil.applyGameDir();
		funkin.mobile.native.NativeCrash.install();
		#end
		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0")  ['--no-lua'] #end);
		#end

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
		#if POLYMOD_ALLOWED
		funkin.modding.PolymodHandler.loadEnabledMods();
		#end
		#if CPPIA_ALLOWED
		funkin.scripting.cppia.CppiaHandler.reloadGlobal();
		#end

		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		Highscore.load();

		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(funkin.scripting.luascript.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		var initialState:Class<FlxState> = cast game.initialState;
		#if mobile
		if (funkin.mobile.storage.CopyState.needsCopy())
			initialState = funkin.mobile.storage.CopyState;
		#end
		addChild(new FlxGame(game.width, game.height, initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));
		#if mobile
		funkin.mobile.input.TouchInput.init();
		funkin.mobile.input.TouchCursor.init();
		funkin.mobile.native.NativeCrash.reportPrevious();
		#end

		fpsVar = new FPSCounter(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}
		#if mobile
		scaleFPSCounter();
		#end

		#if (linux || mac) // fix the app icon not showing up on the Linux Panel / Mac Dock
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onCriticalError);
		#end
		#end

		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end

		// shader coords fix
		FlxG.signals.gameResized.add(function (w, h) {
		     if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
			}

			if (FlxG.game != null)
			resetSpriteCache(FlxG.game);

			#if mobile
			scaleFPSCounter();
			#end
		});
	}

	#if mobile
	static function scaleFPSCounter():Void
	{
		if (fpsVar == null || FlxG.scaleMode == null) return;
		var scale:Float = Math.max(1, Math.min(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y));
		fpsVar.scaleX = fpsVar.scaleY = scale;
		fpsVar.x = FlxG.game.x + 10 * scale;
		fpsVar.y = FlxG.game.y + 3 * scale;
	}
	#end

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		        sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if (CRASH_HANDLER && cpp)
	static function onCriticalError(message:Dynamic):Void
	{
		throw Std.string(message);
	}
	#end

	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error;
		// remove if you're modding and want the crash log message to contain the link
		// please remember to actually modify the link for the github page to report the issues to.
		#if officialBuild
		errMsg += "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine";
		#end
		errMsg += "\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
	}
	#end
}
