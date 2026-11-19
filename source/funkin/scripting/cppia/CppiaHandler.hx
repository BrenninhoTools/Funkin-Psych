package funkin.scripting.cppia;

#if CPPIA_ALLOWED
import cpp.cppia.Module;
import funkin.scripting.cppia.CppiaModule;

@:cppInclude('hx/Scriptable.h')
class CppiaHandler
{
	public static inline final EXTENSION:String = '.cppia';
	public static inline final GLOBAL_FOLDER:String = 'scripts/cppia/';

	public static var globalModules(default, null):Array<CppiaModule> = [];
	public static var onError:CppiaModule->String->Dynamic->Void = null;

	static var loading:CppiaModule = null;

	public static function isScript(file:String):Bool
		return file != null && file.toLowerCase().endsWith(EXTENSION);

	public static function load(path:String):CppiaModule
	{
		if (path == null || !FileSystem.exists(path)) return null;
		try
		{
			var bytes:haxe.io.Bytes = File.getBytes(path);
			var module:Module = Module.fromData(bytes.getData());
			if (module == null) return null;
			var script:CppiaModule = new CppiaModule(path, module);
			script.boot();
			return script;
		}
		catch (e:Dynamic)
		{
			reportError(null, path, e);
			return null;
		}
	}

	public static function start(path:String, ?args:Array<Dynamic>):CppiaModule
	{
		var script:CppiaModule = load(path);
		if (script == null) return null;

		var previous:CppiaModule = loading;
		loading = script;
		try
		{
			var instance:Dynamic = script.createInstance(script.name, args);
			if (instance == null) script.run();
			else if (Std.isOfType(instance, CppiaScript)) (cast instance:CppiaScript).module = script;
		}
		catch (e:Dynamic)
		{
			reportError(script, 'new', e);
		}
		loading = previous;
		return script;
	}

	public static function register(instance:Dynamic):Dynamic
	{
		if (loading != null) loading.addInstance(instance);
		return instance;
	}

	public static function reloadGlobal()
	{
		clearGlobal();
		#if MODS_ALLOWED
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), GLOBAL_FOLDER))
		{
			for (file in FileSystem.readDirectory(folder))
			{
				if (!isScript(file)) continue;
				var script:CppiaModule = start(haxe.io.Path.join([folder, file]));
				if (script != null)
				{
					globalModules.push(script);
					script.call('onLoad');
				}
			}
		}
		#end
	}

	public static function clearGlobal()
	{
		for (script in globalModules)
		{
			script.call('onUnload');
			script.destroy();
		}
		globalModules = [];
	}

	public static function callGlobal(field:String, ?args:Array<Dynamic>):Dynamic
	{
		var result:Dynamic = null;
		for (script in globalModules)
		{
			var value:Dynamic = script.call(field, args);
			if (value != null) result = value;
		}
		return result;
	}

	public static function resolveClass(className:String):Class<Dynamic>
	{
		for (script in globalModules)
		{
			var cls:Class<Dynamic> = script.resolveClass(className);
			if (cls != null) return cls;
		}
		return null;
	}

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
}
#end
