package funkin.data.level;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;

typedef LevelFile =
{
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

class LevelData {
	public static var levelsLoaded:Map<String, LevelData> = new Map<String, LevelData>();
	public static var levelsList:Array<String> = [];
	public var folder:String = '';

	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var fileName:String;

	public static function createLevelFile():LevelFile {
		var weekFile:LevelFile = {
			songs: [["Bopeebo", "face", [146, 113, 253]], ["Fresh", "face", [146, 113, 253]], ["Dad Battle", "face", [146, 113, 253]]],
			#if BASE_GAME_FILES
			weekCharacters: ['dad', 'bf', 'gf'],
			#else
			weekCharacters: ['bf', 'bf', 'gf'],
			#end
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: ''
		};
		return weekFile;
	}

	public function new(weekFile:LevelFile, fileName:String) {
		for (field in Reflect.fields(weekFile))
			if(Reflect.fields(this).contains(field))
				Reflect.setProperty(this, field, Reflect.getProperty(weekFile, field));

		this.fileName = fileName;
	}

	public static function reloadLevelFiles(isStoryMode:Null<Bool> = false)
	{
		levelsList = [];
		levelsLoaded.clear();
		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods(), Paths.getSharedPath()];
		var originalLength:Int = directories.length;

		for (mod in Mods.parseList().enabled)
			directories.push(Paths.mods(mod + '/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath()];
		var originalLength:Int = directories.length;
		#end

		var sexList:Array<String> = [];
		for (listFile in LIST_FILES)
			for (folder in LEVEL_FOLDERS)
				for (entry in CoolUtil.coolTextFile(Paths.getSharedPath(folder + listFile)))
					if (!sexList.contains(entry)) sexList.push(entry);
		for (i in 0...sexList.length) {
			for (j in 0...directories.length) {
				var fileToCheck:String = findLevelFile(directories[j], sexList[i]);
				if(fileToCheck != null && !levelsLoaded.exists(sexList[i])) {
					var week:LevelFile = getLevelFile(fileToCheck);
					if(week != null) {
						var weekFile:LevelData = new LevelData(week, sexList[i]);

						#if MODS_ALLOWED
						if(j >= originalLength) {
							weekFile.folder = directories[j].substring(Paths.mods().length, directories[j].length-1);
						}
						#end

						if(weekFile != null && (isStoryMode == null || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))) {
							levelsLoaded.set(sexList[i], weekFile);
							levelsList.push(sexList[i]);
						}
					}
				}
			}
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			for (directory in levelFolders(directories[i])) {
				var listOfWeeks:Array<String> = [];
				for (listFile in LIST_FILES)
					for (entry in CoolUtil.coolTextFile(directory + listFile))
						if (!listOfWeeks.contains(entry)) listOfWeeks.push(entry);
				for (daWeek in listOfWeeks)
				{
					var path:String = directory + daWeek + '.json';
					if(FileSystem.exists(path))
					{
						addLevel(daWeek, path, directories[i], i, originalLength);
					}
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						addLevel(file.substr(0, file.length - 5), path, directories[i], i, originalLength);
					}
				}
			}
		}
		#end
	}

	public static final LEVEL_FOLDERS:Array<String> = ['data/levels/', 'data/weeks/', 'weeks/'];
	public static final LIST_FILES:Array<String> = ['levelList.txt', 'weekList.txt'];

	public static function levelFolders(directory:String):Array<String>
	{
		var folders:Array<String> = [];
		for (folder in LEVEL_FOLDERS)
		{
			var path:String = directory + folder;
			#if MODS_ALLOWED
			if (FileSystem.exists(path) && FileSystem.isDirectory(path)) folders.push(path);
			#else
			folders.push(path);
			#end
		}
		return folders;
	}

	public static function findLevelFile(directory:String, week:String):String
	{
		for (folder in LEVEL_FOLDERS)
		{
			var path:String = directory + folder + week + '.json';
			#if MODS_ALLOWED
			if (FileSystem.exists(path)) return path;
			#else
			if (OpenFlAssets.exists(path)) return path;
			#end
		}
		return null;
	}

	private static function addLevel(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int)
	{
		if(!levelsLoaded.exists(weekToCheck))
		{
			var week:LevelFile = getLevelFile(path);
			if(week != null)
			{
				var weekFile:LevelData = new LevelData(week, weekToCheck);
				if(i >= originalLength)
				{
					#if MODS_ALLOWED
					weekFile.folder = directory.substring(Paths.mods().length, directory.length-1);
					#end
				}
				if((PlayState.isStoryMode && !weekFile.hideStoryMode) || (!PlayState.isStoryMode && !weekFile.hideFreeplay))
				{
					levelsLoaded.set(weekToCheck, weekFile);
					levelsList.push(weekToCheck);
				}
			}
		}
	}

	private static function getLevelFile(path:String):LevelFile {
		var rawJson:String = null;
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(OpenFlAssets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end

		if(rawJson != null && rawJson.length > 0) {
			return LevelParser.parse(rawJson);
		}
		return null;
	}


	public static function getLevelFileName():String {
		return levelsList[PlayState.storyWeek];
	}

	public static function getCurrentLevel():LevelData {
		return levelsLoaded.get(levelsList[PlayState.storyWeek]);
	}

	public static function setDirectoryFromLevel(?data:LevelData = null) {
		Mods.currentModDirectory = '';
		if(data != null && data.folder != null && data.folder.length > 0) {
			Mods.currentModDirectory = data.folder;
		}
	}
}
