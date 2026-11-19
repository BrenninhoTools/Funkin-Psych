package funkin.modding;

#if POLYMOD_ALLOWED
import polymod.Polymod;
import polymod.Polymod.PolymodError;
import polymod.format.ParseRules;
import funkin.modding.base.ScriptedBaseStage;

class PolymodHandler
{
	public static final API_VERSION_RULE:String = ">=0.0.0";

	public static var loadedModDirs(default, null):Array<String> = [];
	public static var loadedModIds(default, null):Array<String> = [];

	static var importsBuilt:Bool = false;

	public static function loadEnabledMods()
	{
		var dirs:Array<String> = [];
		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled)
			if (Mods.isPolymodMod(mod)) dirs.push(mod);
		#end
		loadModsByDir(dirs);
	}

	public static function loadNoMods()
		loadModsByDir([]);

	public static function loadModsByDir(dirs:Array<String>)
	{
		buildImports();
		Polymod.clearScripts();

		var root:String = modRoot();
		#if sys
		if (!FileSystem.exists(root)) FileSystem.createDirectory(root);
		#end

		var loaded:Array<ModMetadata> = Polymod.init({
			modRoot: root,
			dirs: dirs,
			framework: OPENFL,
			apiVersionRule: API_VERSION_RULE,
			errorCallback: onError,
			parseRules: ParseRules.getDefault(),
			ignoredFiles: Polymod.getDefaultIgnoreList().concat([Mods.PACK_FILE, 'pack.png', 'settings.json', 'credits.txt']),
			skipDependencyErrors: true,
			useScriptedClasses: true,
			loadScriptsAsync: false
		});

		loadedModDirs = [];
		loadedModIds = [];
		if (loaded != null)
			for (mod in loaded)
			{
				loadedModDirs.push(mod.dirName);
				loadedModIds.push(mod.id);
			}
	}

	public static function reload()
	{
		Mods.reload();
	}

	public static function isLoaded(folder:String):Bool
		return loadedModDirs.contains(folder);

	public static function createScriptedStage(name:String):Bool
	{
		if (name == null || !ScriptedBaseStage.listScriptClasses().contains(name)) return false;
		return ScriptedBaseStage.scriptInit(name) != null;
	}

	static function modRoot():String
	{
		var root:String = Paths.mods();
		while (root.endsWith('/')) root = root.substr(0, root.length - 1);
		return root.length > 0 ? root : 'mods';
	}

	static function buildImports()
	{
		if (importsBuilt) return;
		importsBuilt = true;

		Polymod.addDefaultImport(flixel.FlxG);
		Polymod.addDefaultImport(funkin.assets.Paths);
		Polymod.addDefaultImport(funkin.save.Save);
		Polymod.addDefaultImport(funkin.play.Conductor);
		Polymod.addDefaultImport(funkin.util.CoolUtil);
		Polymod.addDefaultImport(funkin.play.PlayState);
		Polymod.addDefaultImport(funkin.modding.Mods);
		Polymod.addImportAlias('flixel.FlxCamera', funkin.graphics.PsychCamera);

		for (path => target in funkin.modding.LegacyClasses.PATHS)
		{
			var cls:Class<Dynamic> = Type.resolveClass(target);
			if (cls != null) Polymod.addImportAlias(path, cls);
		}

		Polymod.blacklistImport('cpp.Lib');
		Polymod.blacklistImport('haxe.Unserializer');
		Polymod.blacklistImport('lime.system.CFFI');
		Polymod.blacklistImport('lime.system.JNI');
	}

	static function onError(error:PolymodError)
	{
		var color:Null<FlxColor> = switch (error.severity)
		{
			case ERROR: FlxColor.RED;
			case WARNING: FlxColor.YELLOW;
			default: null;
		}
		if (color == null) return;

		var text:String = '[Polymod] ${error.code}: ${error.message}';
		#if sys
		Sys.println(text);
		#end
		if (PlayState.instance != null) PlayState.instance.addTextToDebug(text, color);
	}
}
#end
