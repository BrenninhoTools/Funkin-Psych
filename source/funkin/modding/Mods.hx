package funkin.modding;

import openfl.utils.Assets;

typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	all:Array<String>
};

typedef ModInfo = {
	folder:String,
	name:String,
	description:String,
	color:Null<Array<Int>>,
	restart:Bool,
	runsGlobally:Bool,
	iconFramerate:Int,
	discordRPC:Null<String>,
	enabled:Bool,
	polymod:Bool
};

class Mods
{
	public static inline final LIST_FILE:String = 'modsList.txt';
	public static inline final PACK_FILE:String = 'pack.json';
	public static inline final POLYMOD_META_FILE:String = '_polymod_meta.json';

	static public var currentModDirectory:String = '';
	public static final ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];

	public static var updatedOnState:Bool = false;

	static var globalMods:Array<String> = [];
	static var packCache:Map<String, Dynamic> = new Map();
	static var cachedList:ModsList = null;

	inline public static function getGlobalMods():Array<String>
		return globalMods;

	public static function pushGlobalMods():Array<String>
	{
		clearCache();
		globalMods = [];
		for (mod in parseList().enabled)
		{
			var pack:Dynamic = getPack(mod);
			if (pack != null && pack.runsGlobally == true) globalMods.push(mod);
		}
		return globalMods;
	}

	public static function getModDirectories():Array<String>
	{
		var list:Array<String> = [];
		#if MODS_ALLOWED
		var modsFolder:String = Paths.mods();
		if (FileSystem.exists(modsFolder))
		{
			for (folder in FileSystem.readDirectory(modsFolder))
			{
				var path:String = haxe.io.Path.join([modsFolder, folder]);
				if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder.toLowerCase()) && !list.contains(folder))
					list.push(folder);
			}
		}
		#end
		return list;
	}

	public static function mergeAllTextsNamed(path:String, ?defaultDirectory:String = null, allowDuplicates:Bool = false):Array<String>
	{
		if (defaultDirectory == null) defaultDirectory = Paths.getSharedPath();
		defaultDirectory = defaultDirectory.trim();
		if (!defaultDirectory.endsWith('/')) defaultDirectory += '/';
		if (!defaultDirectory.startsWith('assets/')) defaultDirectory = 'assets/$defaultDirectory';

		var mergedList:Array<String> = [];
		var paths:Array<String> = directoriesWithFile(defaultDirectory, path);

		var defaultPath:String = defaultDirectory + path;
		if (paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
			for (value in CoolUtil.coolTextFile(file))
				if ((allowDuplicates || !mergedList.contains(value)) && value.length > 0)
					mergedList.push(value);
		return mergedList;
	}

	public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true):Array<String>
	{
		var foldersToCheck:Array<String> = [];
		for (name in funkin.assets.AssetAliases.variants(fileToFind))
			for (folder in directoriesWithExactFile(path, name, mods))
				if (!foldersToCheck.contains(folder)) foldersToCheck.push(folder);
		return foldersToCheck;
	}

	static function directoriesWithExactFile(path:String, fileToFind:String, mods:Bool = true):Array<String>
	{
		var foldersToCheck:Array<String> = [];
		if (FileSystem.exists(path + fileToFind))
			foldersToCheck.push(path + fileToFind);

		if (Paths.currentLevel != null && Paths.currentLevel != path)
		{
			var levelPath:String = Paths.getFolderPath(fileToFind, Paths.currentLevel);
			if (!foldersToCheck.contains(levelPath) && FileSystem.exists(levelPath))
				foldersToCheck.push(levelPath);
		}

		#if MODS_ALLOWED
		if (mods)
		{
			for (mod in getGlobalMods())
			{
				var folder:String = Paths.mods(mod + '/' + fileToFind);
				if (FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}

			var rootFolder:String = Paths.mods(fileToFind);
			if (FileSystem.exists(rootFolder) && !foldersToCheck.contains(rootFolder)) foldersToCheck.push(rootFolder);

			if (currentModDirectory != null && currentModDirectory.length > 0)
			{
				var folder:String = Paths.mods(currentModDirectory + '/' + fileToFind);
				if (FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}
		}
		#end
		return foldersToCheck;
	}

	public static function getPack(?folder:String = null):Dynamic
	{
		#if MODS_ALLOWED
		if (folder == null) folder = currentModDirectory;
		if (folder == null) return null;
		if (packCache.exists(folder)) return packCache.get(folder);

		var pack:Dynamic = null;
		var path:String = Paths.mods(folder + '/' + PACK_FILE);
		if (FileSystem.exists(path))
		{
			try
			{
				#if sys
				var rawJson:String = File.getContent(path);
				#else
				var rawJson:String = Assets.getText(path);
				#end
				if (rawJson != null && rawJson.length > 0) pack = tjson.TJSON.parse(rawJson);
			}
			catch (e:Dynamic)
			{
				pack = null;
			}
		}
		packCache.set(folder, pack);
		return pack;
		#else
		return null;
		#end
	}

	public static function getMetadata(folder:String):ModInfo
	{
		var pack:Dynamic = getPack(folder);
		var color:Null<Array<Int>> = null;
		if (pack != null && pack.color != null && Std.isOfType(pack.color, Array)) color = cast pack.color;

		return {
			folder: folder,
			name: pack != null && pack.name != null ? Std.string(pack.name) : folder,
			description: pack != null && pack.description != null ? Std.string(pack.description) : '',
			color: color,
			restart: pack != null && pack.restart == true,
			runsGlobally: pack != null && pack.runsGlobally == true,
			iconFramerate: pack != null && pack.iconFramerate != null ? Std.int(pack.iconFramerate) : 10,
			discordRPC: pack != null && pack.discordRPC != null ? Std.string(pack.discordRPC) : null,
			enabled: isEnabled(folder),
			polymod: isPolymodMod(folder)
		};
	}

	public static function isPolymodMod(folder:String):Bool
	{
		#if MODS_ALLOWED
		return folder != null && FileSystem.exists(Paths.mods(folder + '/' + POLYMOD_META_FILE));
		#else
		return false;
		#end
	}

	public static function isEnabled(folder:String):Bool
		return parseList().enabled.contains(folder);

	public static function getEnabledMods():Array<String>
		return parseList().enabled.copy();

	public static function parseList():ModsList
	{
		if (!updatedOnState) updateModList();
		if (cachedList != null) return {enabled: cachedList.enabled.copy(), disabled: cachedList.disabled.copy(), all: cachedList.all.copy()};

		var list:ModsList = {enabled: [], disabled: [], all: []};
		#if MODS_ALLOWED
		try
		{
			for (mod in CoolUtil.coolTextFile(LIST_FILE))
			{
				if (mod.trim().length < 1) continue;
				var data:Array<String> = mod.split('|');
				list.all.push(data[0]);
				if (data[1] == '1') list.enabled.push(data[0]);
				else list.disabled.push(data[0]);
			}
		}
		catch (e:Dynamic) {}
		#end
		cachedList = list;
		return {enabled: list.enabled.copy(), disabled: list.disabled.copy(), all: list.all.copy()};
	}

	public static function updateModList()
	{
		#if MODS_ALLOWED
		var entries:Array<{folder:String, enabled:Bool}> = [];
		var added:Array<String> = [];
		try
		{
			for (mod in CoolUtil.coolTextFile(LIST_FILE))
			{
				var data:Array<String> = mod.split('|');
				var folder:String = data[0].trim();
				if (folder.length > 0 && isModFolder(folder) && !added.contains(folder))
				{
					added.push(folder);
					entries.push({folder: folder, enabled: data[1] == '1'});
				}
			}
		}
		catch (e:Dynamic) {}

		for (folder in getModDirectories())
		{
			if (folder.trim().length > 0 && isModFolder(folder) && !added.contains(folder))
			{
				added.push(folder);
				entries.push({folder: folder, enabled: true});
			}
		}

		writeList(entries);
		#end
		updatedOnState = true;
	}

	public static function saveList(entries:Array<{folder:String, enabled:Bool}>)
	{
		#if MODS_ALLOWED
		writeList(entries);
		#end
		reload();
	}

	public static function setEnabled(folder:String, enabled:Bool)
	{
		var list:ModsList = parseList();
		saveList([for (mod in list.all) {folder: mod, enabled: mod == folder ? enabled : list.enabled.contains(mod)}]);
	}

	public static function reload()
	{
		clearCache();
		updatedOnState = false;
		pushGlobalMods();
		loadTopMod();
		#if POLYMOD_ALLOWED
		PolymodHandler.loadEnabledMods();
		#end
		#if CPPIA_ALLOWED
		funkin.scripting.cppia.CppiaHandler.reloadGlobal();
		#end
	}

	public static function clearCache()
	{
		packCache.clear();
		cachedList = null;
	}

	public static function loadTopMod()
	{
		#if mobile
		Paths.clearModPathCache();
		#end
		currentModDirectory = '';

		#if MODS_ALLOWED
		var list:Array<String> = parseList().enabled;
		if (list != null && list[0] != null)
			currentModDirectory = list[0];
		#end
	}

	static function isModFolder(folder:String):Bool
	{
		#if MODS_ALLOWED
		var path:String = Paths.mods(folder);
		return FileSystem.exists(path) && FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder.toLowerCase());
		#else
		return false;
		#end
	}

	static function writeList(entries:Array<{folder:String, enabled:Bool}>)
	{
		#if MODS_ALLOWED
		var lines:Array<String> = [for (entry in entries) entry.folder + '|' + (entry.enabled ? '1' : '0')];
		File.saveContent(LIST_FILE, lines.join('\n'));
		cachedList = null;
		packCache.clear();
		#end
	}
}
