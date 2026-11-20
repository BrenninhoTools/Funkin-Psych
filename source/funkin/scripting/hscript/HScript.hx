package funkin.scripting.hscript;

import flixel.FlxBasic;
import funkin.play.character.Character;
import funkin.scripting.luascript.LuaUtils;
import funkin.scripting.luascript.CustomSubstate;

#if LUA_ALLOWED
import funkin.scripting.luascript.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import hscript.Expr;
import funkin.scripting.hscript.ScriptParser;
import funkin.scripting.hscript.ScriptInterp;
import funkin.scripting.hscript.ScriptImports;

typedef HScriptInfos = {
	> haxe.PosInfos,
	var ?funcName:String;
	var ?showLine:Null<Bool>;
	#if LUA_ALLOWED
	var ?isLua:Null<Bool>;
	#end
}

typedef HScriptCall = {
	var funName:String;
	var signature:Dynamic;
	var returnValue:Dynamic;
}

typedef ScriptError = hscript.Expr.Error;

class HScript
{
	public static var instances:Map<String, HScript> = new Map();

	public var filePath:String;
	public var modFolder:String;
	public var origin:String;
	public var scriptName:String;
	public var scriptCode:String;
	public var returnValue:Dynamic;
	public var active(default, null):Bool = true;
	public var interp(default, null):ScriptInterp;
	public var program(default, null):Expr;

	#if LUA_ALLOWED
	public var parentLua:FunkinLua;

	public static function initHaxeModule(parent:FunkinLua)
	{
		if (parent.hscript == null)
			parent.hscript = new HScript(parent);
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String, ?varsToBring:Any = null)
	{
		var hs:HScript = parent.hscript;
		if (hs == null)
		{
			try
			{
				parent.hscript = new HScript(parent, code, varsToBring);
			}
			catch (e:ScriptError)
			{
				var pos:HScriptInfos = errorPos(e, parent.lastCalledFunction != '' ? parent.lastCalledFunction : null);
				pos.isLua = true;
				error(errorMessage(e), pos);
				parent.hscript = null;
			}
			return;
		}

		try
		{
			hs.scriptCode = code;
			hs.varsToBring = varsToBring;
			hs.parse(true);
			hs.returnValue = hs.execute();
		}
		catch (e:ScriptError)
		{
			var pos:HScriptInfos = errorPos(e, parent.lastCalledFunction != '' ? parent.lastCalledFunction : null);
			pos.isLua = true;
			error(errorMessage(e), pos);
			hs.returnValue = null;
		}
	}
	#end

	public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false)
	{
		if (file == null) file = '';

		filePath = file;
		scriptCode = file;
		if (filePath.length > 0)
		{
			origin = filePath;
			#if MODS_ALLOWED
			var modsPath:String = Paths.mods();
			if (filePath.startsWith(modsPath))
			{
				var modName:String = filePath.substr(modsPath.length).split('/')[0];
				if (Mods.currentModDirectory == modName || Mods.getGlobalMods().contains(modName))
					modFolder = modName;
			}
			#end
		}

		if (parent == null && file.length > 0)
		{
			var path:String = file.replace('\\', '/');
			if (path.contains('/') && !path.contains('\n'))
			{
				#if sys
				scriptCode = File.getContent(path);
				#else
				scriptCode = openfl.Assets.getText(path);
				#end
				scriptName = path;
			}
		}

		#if LUA_ALLOWED
		parentLua = parent;
		if (parent != null)
		{
			origin = parent.scriptName;
			modFolder = parent.modFolder;
			if (scriptName == null) scriptName = parent.scriptName;
		}
		#end
		if (scriptName == null) scriptName = 'hscript';

		interp = new ScriptInterp();
		interp.parentInstance = FlxG.state;
		interp.onWarning = function(message:String, pos:haxe.PosInfos) warn(message, cast pos);
		preset();
		this.varsToBring = varsToBring;

		if (parent == null && filePath.length > 0 && scriptName != 'hscript')
			instances.set(scriptName, this);

		if (!manualRun)
		{
			try
			{
				returnValue = execute();
			}
			catch (e:ScriptError)
			{
				returnValue = null;
				destroy();
				throw e;
			}
		}
	}

	public function parse(force:Bool = false):Expr
	{
		if (program != null && !force) return program;
		program = toScriptError(function() return new ScriptParser().parseScript(scriptCode, scriptName));
		return program;
	}

	public function execute():Dynamic
	{
		if (!active || interp == null) return null;
		if (program == null) parse();
		return toScriptError(function() return interp.execute(program));
	}

	public function set(name:String, value:Dynamic):Void
	{
		if (interp != null) interp.variables.set(name, value);
	}

	public function get(name:String):Dynamic
	{
		if (interp == null) return null;
		return interp.variables.get(name);
	}

	public function exists(name:String):Bool
		return interp != null && interp.variables.exists(name);

	public function remove(name:String):Bool
		return interp != null && interp.variables.remove(name);

	public function posInfos():HScriptInfos
	{
		var pos:HScriptInfos = interp != null ? cast interp.posInfos() : cast {fileName: scriptName, lineNumber: 0};
		#if LUA_ALLOWED
		if (parentLua != null)
		{
			pos.isLua = true;
			if (parentLua.lastCalledFunction != '') pos.funcName = parentLua.lastCalledFunction;
		}
		#end
		return pos;
	}

	public function call(funcToRun:String, ?args:Array<Dynamic>):HScriptCall
	{
		if (funcToRun == null || interp == null || !active) return null;

		if (!exists(funcToRun))
		{
			error('No function named: $funcToRun', posInfos());
			return null;
		}

		var func:Dynamic = interp.variables.get(funcToRun);
		if (!Reflect.isFunction(func))
		{
			error('$funcToRun is not a function', posInfos());
			return null;
		}

		try
		{
			var ret:Dynamic = Reflect.callMethod(null, func, args != null ? args : []);
			return {funName: funcToRun, signature: func, returnValue: ret};
		}
		catch (e:ScriptError)
		{
			var pos:HScriptInfos = errorPos(e, funcToRun);
			#if LUA_ALLOWED
			if (parentLua != null)
			{
				pos.isLua = true;
				if (parentLua.lastCalledFunction != '') pos.funcName = parentLua.lastCalledFunction;
			}
			#end
			error(errorMessage(e), pos);
		}
		catch (e:Dynamic)
		{
			var pos:HScriptInfos = posInfos();
			if (pos.funcName == null) pos.funcName = funcToRun;
			error(Std.string(e), pos);
		}
		return null;
	}

	public function callIfExists(funcToRun:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!exists(funcToRun)) return null;
		var result:HScriptCall = call(funcToRun, args);
		return result != null ? result.returnValue : null;
	}

	public function destroy()
	{
		if (!active) return;
		active = false;
		if (scriptName != null && instances.get(scriptName) == this) instances.remove(scriptName);
		if (PlayState.instance != null && PlayState.instance.hscriptArray != null)
			PlayState.instance.hscriptArray.remove(this);
		#if LUA_ALLOWED parentLua = null; #end
		origin = null;
		program = null;
		interp = null;
	}

	var varsToBring(default, set):Any = null;

	function preset()
	{
		set('Type', Type);
		#if sys
		set('File', File);
		set('FileSystem', FileSystem);
		#end
		set('FlxG', flixel.FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		#if foxlite
		set('Scene3D', funkin.graphics.three.Scene3D);
		#end
		set('FlxText', flixel.text.FlxText);
		set('FlxCamera', funkin.graphics.PsychCamera);
		set('PsychCamera', funkin.graphics.PsychCamera);
		set('FunkinSound', funkin.audio.FunkinSound);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxColor', CustomFlxColor);
		set('Countdown', funkin.play.stages.BaseStage.Countdown);
		set('PlayState', PlayState);
		set('Paths', Paths);
		set('Conductor', Conductor);
		set('Save', funkin.save.Save);
		set('ClientPrefs', funkin.save.Save);
		#if ACHIEVEMENTS_ALLOWED
		set('Achievements', Achievements);
		#end
		set('Character', Character);
		set('Alphabet', Alphabet);
		set('Note', funkin.play.notes.Note);
		set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		set('ErrorHandledRuntimeShader', funkin.shaders.ErrorHandledShader.ErrorHandledRuntimeShader);
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);
		set('StringTools', StringTools);
		set('MobileAPI', funkin.mobile.MobileAPI);
		set('isMobile', funkin.mobile.MobileAPI.isMobile);
		set('vibrate', funkin.mobile.MobileAPI.vibrate);
		#if mobile
		set('TouchInput', funkin.mobile.input.TouchInput);
		set('VirtualPad', funkin.mobile.controls.VirtualPad);
		#end
		#if flxanimate
		set('FlxAnimate', FlxAnimate);
		#end

		set('setVar', function(name:String, value:Dynamic) {
			MusicBeatState.getVariables().set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			var result:Dynamic = null;
			if(MusicBeatState.getVariables().exists(name)) result = MusicBeatState.getVariables().get(name);
			return result;
		});
		set('removeVar', function(name:String)
		{
			if(MusicBeatState.getVariables().exists(name))
			{
				MusicBeatState.getVariables().remove(name);
				return true;
			}
			return false;
		});
		set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			PlayState.instance.addTextToDebug(text, color);
		});
		set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					error('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', posInfos());
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});

		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadJustPressed', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		set('gamepadPressed', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});
		set('gamepadReleased', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('keyJustPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		set('keyPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		set('keyReleased', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});

		#if LUA_ALLOWED
		set('createGlobalCallback', function(name:String, func:Dynamic)
		{
			for (script in PlayState.instance.luaArray)
				if(script != null && script.lua != null && !script.closed)
					Lua_helper.add_callback(script.lua, name, func);

			FunkinLua.customFunctions.set(name, func);
		});

		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null)
		{
			if(funk == null) funk = parentLua;
			
			if(funk != null) funk.addLocalCallback(name, func);
			else error('createCallback ($name): 3rd argument is null', posInfos());
		});
		#end

		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			var path:String = (libPackage != null && libPackage.length > 0) ? libPackage + '.' + libName : libName;
			var value:Dynamic = ScriptImports.resolve(path);
			if (value == null)
			{
				error('addHaxeLibrary: Could not find $path', posInfos());
				return;
			}
			set(libName, value);
		});
		set('importClass', function(path:String, ?alias:String) return interp.importPath(path, alias));
		set('addImportProxy', function(path:String, value:Dynamic) ScriptImports.addProxy(path, value));
		set('getScript', function(path:String) return instances.get(path));
		set('callOnScripts', function(funcName:String, ?args:Array<Dynamic>) {
			if (PlayState.instance == null) return null;
			return PlayState.instance.callOnScripts(funcName, args);
		});
		set('setOnScripts', function(name:String, value:Dynamic) {
			if (PlayState.instance != null) PlayState.instance.setOnScripts(name, value);
			return value;
		});
		#if LUA_ALLOWED
		set('parentLua', parentLua);
		#else
		set('parentLua', null);
		#end
		set('this', this);
		set('game', FlxG.state);
		set('controls', Controls.instance);

		set('buildTarget', LuaUtils.getBuildTarget());
		set('customSubstate', CustomSubstate.instance);
		set('customSubstateName', CustomSubstate.name);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
	}

	function set_varsToBring(values:Any):Any
	{
		if (varsToBring != null)
			for (key in Reflect.fields(varsToBring))
				remove(key.trim());

		if (values != null)
			for (key in Reflect.fields(values))
				set(key.trim(), Reflect.field(values, key));

		return varsToBring = values;
	}

	function toScriptError<T>(run:Void->T):T
	{
		try
		{
			return run();
		}
		catch (e:ScriptError)
		{
			throw e;
		}
		catch (e:Dynamic)
		{
			var pos:haxe.PosInfos = interp != null ? interp.posInfos() : null;
			#if hscriptPos
			throw new ScriptError(ECustom(Std.string(e)), 0, 0, pos != null ? pos.fileName : scriptName, pos != null ? pos.lineNumber : 0);
			#else
			throw ECustom(Std.string(e));
			#end
		}
	}

	public static function errorMessage(e:ScriptError):String
	{
		return switch (#if hscriptPos e.e #else e #end)
		{
			case EInvalidChar(c): 'Invalid character: \'' + (StringTools.isEof(c) ? 'EOF' : String.fromCharCode(c)) + '\' ($c)';
			case EUnexpected(s): 'Unexpected token: "$s"';
			case EUnterminatedString: 'Unterminated string';
			case EUnterminatedComment: 'Unterminated comment';
			case EInvalidPreprocessor(msg): 'Invalid preprocessor ($msg)';
			case EUnknownVariable(v): 'Unknown variable: $v';
			case EInvalidIterator(v): 'Invalid iterator: $v';
			case EInvalidOp(op): 'Invalid operator: $op';
			case EInvalidAccess(f): 'Invalid access to field $f';
			case ECustom(msg): msg;
		}
	}

	public static function errorPos(e:ScriptError, ?funcName:String):HScriptInfos
	{
		#if hscriptPos
		var pos:HScriptInfos = cast {fileName: e.origin, lineNumber: e.line, className: '', methodName: ''};
		#else
		var pos:HScriptInfos = cast {fileName: 'hscript', lineNumber: 0, className: '', methodName: ''};
		#end
		if (funcName != null) pos.funcName = funcName;
		return pos;
	}

	public static function reportError(e:ScriptError, ?file:String)
	{
		var pos:HScriptInfos = errorPos(e);
		if (file != null && (pos.fileName == null || pos.fileName == 'hscript')) pos.fileName = file;
		error(errorMessage(e), pos);
	}

	public static function warn(message:String, ?pos:HScriptInfos)
		report('WARNING', FlxColor.YELLOW, message, pos);

	public static function error(message:String, ?pos:HScriptInfos)
		report('ERROR', FlxColor.RED, message, pos);

	public static function fatal(message:String, ?pos:HScriptInfos)
		report('FATAL', 0xFFBB0000, message, pos);

	static function report(level:String, color:FlxColor, message:String, ?pos:HScriptInfos)
	{
		var info:String = '';
		if (pos != null)
		{
			var showLine:Bool = pos.showLine != false;
			if (pos.funcName != null) info += '(${pos.funcName}) - ';
			info += '${pos.fileName}:';
			#if LUA_ALLOWED
			if (pos.isLua == true)
			{
				info += 'HScript:';
				showLine = false;
			}
			#end
			if (showLine) info += '${pos.lineNumber}:';
			info += ' ';
		}
		var text:String = '$level: $info$message';
		#if sys
		Sys.println(text);
		#end
		if (PlayState.instance != null)
			PlayState.instance.addTextToDebug(text, color);
	}

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			initHaxeModuleCode(funk, codeToRun, varsToBring);
			if (funk.hscript != null)
			{
				if (funcToRun != null)
				{
					var retVal:HScriptCall = funk.hscript.call(funcToRun, funcArgs);
					if (retVal != null)
						return LuaUtils.isLuaSupported(retVal.returnValue) ? retVal.returnValue : null;
				}
				else if (funk.hscript.returnValue != null)
				{
					return LuaUtils.isLuaSupported(funk.hscript.returnValue) ? funk.hscript.returnValue : null;
				}
			}
			return null;
		});

		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			if (funk.hscript != null)
			{
				var retVal:HScriptCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
					return LuaUtils.isLuaSupported(retVal.returnValue) ? retVal.returnValue : null;
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: funk.scriptName, showLine: false};
				if (funk.lastCalledFunction != '') pos.funcName = funk.lastCalledFunction;
				error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});

		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			if (libName == null) libName = '';
			var path:String = (libPackage != null && libPackage.length > 0) ? libPackage + '.' + libName : libName;
			var value:Dynamic = ScriptImports.resolve(path);

			if (funk.hscript == null)
				initHaxeModule(funk);

			var pos:HScriptInfos = funk.hscript.posInfos();
			pos.showLine = false;
			if (funk.lastCalledFunction != '') pos.funcName = funk.lastCalledFunction;

			if (value != null) funk.hscript.set(libName, value);
			else error('addHaxeLibrary: Could not find $path', pos);

			FunkinLua.lastCalledScript = funk;
			if (FunkinLua.getBool('luaDebugMode') && FunkinLua.getBool('luaDeprecatedWarnings'))
				warn("addHaxeLibrary is deprecated! Import classes through \"import\" in HScript!", pos);
		});
	}
	#end
}

class CustomFlxColor
{
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	public static function fromInt(Value:Int):Int 
		return cast FlxColor.fromInt(Value);

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);

	public static function fromString(str:String):Int
		return cast FlxColor.fromString(str);
}
#else
class HScript
{
	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
	}
	#end
}
#end
