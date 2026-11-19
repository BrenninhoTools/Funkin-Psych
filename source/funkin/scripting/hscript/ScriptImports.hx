package funkin.scripting.hscript;

#if HSCRIPT_ALLOWED
import funkin.backend.LegacyClasses;

class ScriptImports
{
	static final PACKAGES:Array<String> = [
		"flixel", "openfl", "lime", "haxe", "sys", "funkin", "hxvlc", "flxanimate", "llua", "hscript",
		"backend", "objects", "states", "substates", "options", "psychlua", "cutscenes", "shaders", "mobile"
	];

	static var proxies:Map<String, Dynamic>;
	static var blocked:Array<String> = [];
	static var cache:Map<String, Dynamic> = new Map();

	public static function addProxy(path:String, value:Dynamic)
	{
		init();
		proxies.set(path, value);
		cache.remove(path);
	}

	public static function block(path:String)
	{
		if (!blocked.contains(path)) blocked.push(path);
	}

	public static function isBlocked(path:String):Bool
	{
		for (entry in blocked)
			if (path == entry || (entry.endsWith(".*") && path.startsWith(entry.substr(0, entry.length - 1))))
				return true;
		return false;
	}

	public static function isPackage(id:String):Bool
		return PACKAGES.contains(id);

	public static function resolve(path:String):Dynamic
	{
		if (path == null || path.length == 0) return null;
		init();
		if (proxies.exists(path)) return proxies.get(path);
		if (cache.exists(path)) return cache.get(path);

		var value:Dynamic = Type.resolveClass(path);
		if (value == null) value = Type.resolveEnum(path);
		if (value == null && LegacyClasses.PATHS.exists(path))
		{
			var newPath:String = LegacyClasses.PATHS.get(path);
			value = Type.resolveClass(newPath);
			if (value == null) value = Type.resolveEnum(newPath);
		}
		#if CPPIA_ALLOWED
		if (value == null) return funkin.scripting.cppia.CppiaHandler.resolveClass(path);
		#end
		if (value != null) cache.set(path, value);
		return value;
	}

	public static function defaults():Map<String, Dynamic>
	{
		var values:Map<String, Dynamic> = new Map();
		values.set("Std", Std);
		values.set("Math", Math);
		values.set("Reflect", Reflect);
		values.set("Type", Type);
		values.set("StringTools", StringTools);
		values.set("Lambda", Lambda);
		values.set("Date", Date);
		values.set("DateTools", DateTools);
		values.set("EReg", EReg);
		values.set("Xml", Xml);
		values.set("Json", haxe.Json);
		values.set("StringBuf", StringBuf);
		return values;
	}

	static function init()
	{
		if (proxies != null) return;
		proxies = new Map();
		proxies.set("flixel.FlxCamera", funkin.backend.PsychCamera);
		proxies.set("flixel.util.FlxColor", funkin.scripting.hscript.HScript.CustomFlxColor);
		var basePoint:Dynamic = Type.resolveClass("flixel.math.FlxBasePoint");
		if (basePoint != null) proxies.set("flixel.math.FlxPoint", basePoint);
		#if mobile
		proxies.set("mobile.TouchInput", funkin.mobile.input.TouchInput);
		proxies.set("mobile.VirtualPad", funkin.mobile.controls.VirtualPad);
		proxies.set("mobile.MobileButton", funkin.mobile.controls.MobileButton);
		proxies.set("mobile.Hitbox", funkin.mobile.controls.Hitbox);
		proxies.set("mobile.StorageUtil", funkin.mobile.storage.StorageUtil);
		#end
	}
}
#end
