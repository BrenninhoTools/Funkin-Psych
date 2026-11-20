package funkin.ui.charSelect;

import haxe.Json;

class PlayerData
{
	public static inline var DEFAULT:String = 'bf';

	static var cache:Map<String, Dynamic> = null;

	public static function reload()
	{
		cache = new Map();
		for (file in Paths.readDirectory('data/players', '.json'))
		{
			var id:String = file.substr(0, file.length - 5);
			var raw:String = Paths.getTextFromFile('data/players/$file');
			if (raw == null) continue;
			try
			{
				cache.set(id, Json.parse(raw));
			}
			catch (e:Dynamic) {}
		}
	}

	public static function list():Array<String>
	{
		if (cache == null) reload();
		var ids:Array<String> = [for (id in cache.keys()) id];
		ids.sort(Reflect.compare);
		return ids;
	}

	public static function get(id:String):Dynamic
	{
		if (cache == null) reload();
		return id != null ? cache.get(id) : null;
	}

	public static function exists(id:String):Bool
		return get(id) != null;

	public static function isUnlocked(id:String):Bool
	{
		var data:Dynamic = get(id);
		return data != null && data.unlocked != false;
	}

	public static function freeplayDJ(id:String):Dynamic
	{
		var data:Dynamic = get(id);
		return data != null ? data.freeplayDJ : null;
	}

	public static function styleId(id:String):String
	{
		var data:Dynamic = get(id);
		return data != null && data.freeplayStyle != null ? Std.string(data.freeplayStyle) : DEFAULT;
	}

	public static function charSelect(id:String):Dynamic
	{
		var data:Dynamic = get(id);
		return data != null ? data.charSelect : null;
	}

	public static function owns(id:String, character:String):Bool
	{
		var data:Dynamic = get(id);
		if (data == null || data.ownedChars == null) return false;
		var owned:Array<Dynamic> = data.ownedChars;
		for (entry in owned)
			if (Std.string(entry) == character) return true;
		return false;
	}

	public static function ownerOf(character:String):String
	{
		for (id in list())
			if (owns(id, character)) return id;
		return null;
	}

	public static function name(id:String):String
	{
		var data:Dynamic = get(id);
		return data != null && data.name != null ? Std.string(data.name) : id;
	}
}
