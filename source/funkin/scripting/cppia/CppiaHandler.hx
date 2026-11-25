package funkin.scripting.cppia;

#if CPPIA_ALLOWED
import cppia.Cppia;
import cppia.CppiaError;
import cppia.CppiaGroup;
import funkin.scripting.cppia.CppiaModule;

class CppiaHandler
{
	public static inline final EXTENSION:String = Cppia.EXTENSION;
	public static inline final GLOBAL_FOLDER:String = 'scripts/cppia/';

	public static var global(default, null):CppiaGroup = new CppiaGroup();
	public static var globalModules(get, never):Array<CppiaModule>;
	public static var onError:CppiaModule->String->Dynamic->Void = null;

	static var initialized:Bool = false;

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;
		Cppia.onError = handleError;
		#if debug
		global.hotReload = true;
		Cppia.profiling = true;
		#end
		global.onReload = function(module) module.call('onLoad');
		FlxG.signals.postUpdate.add(global.update);
	}

	public static inline function isScript(file:String):Bool
		return Cppia.isScript(file);

	public static function load(path:String):CppiaModule
	{
		init();
		return Cppia.load(path, false);
	}

	public static function start(path:String, ?args:Array<Dynamic>):CppiaModule
	{
		init();
		return Cppia.load(path, true, args);
	}

	public static inline function register(instance:Dynamic):Dynamic
		return Cppia.register(instance);

	public static function reloadGlobal()
	{
		init();
		clearGlobal();
		#if MODS_ALLOWED
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), GLOBAL_FOLDER))
			for (script in global.loadFolder(folder))
				script.call('onLoad');
		#end
	}

	public static function clearGlobal()
	{
		global.call('onUnload');
		global.destroy();
	}

	public static inline function callGlobal(field:String, ?args:Array<Dynamic>):Dynamic
		return global.call(field, args);

	public static inline function resolveClass(className:String):Class<Dynamic>
		return global.resolveClass(className);

	static function handleError(error:CppiaError):Void
		reportError(error.module, error.field, error.error);

	public static function reportError(script:CppiaModule, field:String, error:Dynamic)
	{
		if (onError != null)
		{
			onError(script, field, error);
			return;
		}
		var origin:String = script != null ? script.path : field;
		var message:String = 'Cppia error in $origin';
		if (script != null && field != null) message += ' ($field)';
		FlxG.log.warn('$message: $error');
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		if (PlayState.instance != null) PlayState.instance.addTextToDebug('$message: $error', FlxColor.RED);
		#end
	}

	static inline function get_globalModules():Array<CppiaModule>
		return global.modules;
}
#end
