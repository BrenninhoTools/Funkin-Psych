package funkin.data.menu;

import funkin.data.DataUtil;
import funkin.data.ui.UIData;

class MenuData extends UIData
{
	public static inline final VERSION:String = "1.0.0";
	public static inline final FOLDER:String = 'menus';

	public function new(id:String, data:Dynamic)
		super(id, data);

	public static function exists(id:String):Bool
		return UIData.fileExists(FOLDER, id);

	public static function load(id:String, defaults:Dynamic):MenuData
	{
		UIData.clearFileCache();
		return new MenuData(id, UIData.loadMerged(FOLDER, id, defaults));
	}

	public function list(name:String):Array<Dynamic>
	{
		var value:Dynamic = Reflect.field(data, name);
		return value != null && Std.isOfType(value, Array) ? value : [];
	}

	public function sound(name:String, fallback:String):String
	{
		var sounds:Dynamic = data.sounds;
		var value:Dynamic = sounds != null ? Reflect.field(sounds, name) : null;
		return value != null ? Std.string(value) : fallback;
	}

	public static function requirementMet(info:Dynamic):Bool
	{
		if (info == null) return false;
		var requires:Dynamic = info.requires;
		if (requires == null) return true;
		var list:Array<Dynamic> = Std.isOfType(requires, Array) ? requires : [requires];
		for (entry in list)
			if (!flagEnabled(Std.string(entry))) return false;
		return true;
	}

	public static function flagEnabled(flag:String):Bool
	{
		var negate:Bool = flag.startsWith('!');
		if (negate) flag = flag.substr(1);
		var enabled:Bool = switch (flag.toLowerCase())
		{
			case 'mods': #if MODS_ALLOWED true #else false #end;
			case 'achievements': #if ACHIEVEMENTS_ALLOWED true #else false #end;
			case 'mobile': #if mobile true #else false #end;
			case 'desktop': #if desktop true #else false #end;
			case 'lua': #if LUA_ALLOWED true #else false #end;
			case 'hscript': #if HSCRIPT_ALLOWED true #else false #end;
			case 'base_game': #if BASE_GAME_FILES true #else false #end;
			default: true;
		};
		return negate ? !enabled : enabled;
	}
}
