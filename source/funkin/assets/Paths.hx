package funkin.assets;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.media.Sound;
import haxe.io.Bytes;

#if MODS_ALLOWED
import funkin.modding.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";
	inline public static var IMAGE_EXT = "png";
	inline public static var SHARED_FOLDER = "shared";
	inline public static var PRELOAD_FOLDER = "preload";

	public static var SOUND_FALLBACK_EXTS:Array<String> = #if web [] #else ["ogg", "mp3", "wav", "flac"] #end;
	public static var IMAGE_FALLBACK_EXTS:Array<String> = ["jpg", "jpeg"];
	public static var cachePaths:Bool = true;

	static var pathCache:Map<String, String> = new Map();
	static var missingFiles:Map<String, Bool> = new Map();
	#if target.threaded
	static var cacheMutex:sys.thread.Mutex = new sys.thread.Mutex();
	#end

	public static function clearPathCache():Void
	{
		lockCache();
		pathCache.clear();
		missingFiles.clear();
		unlockCache();
	}

	static inline function lockCache():Void
	{
		#if target.threaded
		cacheMutex.acquire();
		#end
	}

	static inline function unlockCache():Void
	{
		#if target.threaded
		cacheMutex.release();
		#end
	}

	static function isMissing(file:String):Bool
	{
		lockCache();
		var missing:Bool = missingFiles.exists(file);
		unlockCache();
		return missing;
	}

	static function markMissing(file:String):Void
	{
		lockCache();
		missingFiles.set(file, true);
		unlockCache();
	}

	public static var dumpExclusions(get, set):Array<String>;
	public static var localTrackedAssets(get, set):Array<String>;
	public static var currentTrackedAssets(get, set):Map<String, FlxGraphic>;
	public static var currentTrackedSounds(get, set):Map<String, Sound>;

	static inline function get_dumpExclusions():Array<String> return AssetCache.exclusions;
	static inline function set_dumpExclusions(v:Array<String>):Array<String> return AssetCache.exclusions = v;
	static inline function get_localTrackedAssets():Array<String> return AssetCache.localKeys;
	static inline function set_localTrackedAssets(v:Array<String>):Array<String> return AssetCache.localKeys = v;
	static inline function get_currentTrackedAssets():Map<String, FlxGraphic> return AssetCache.graphics;
	static inline function set_currentTrackedAssets(v:Map<String, FlxGraphic>):Map<String, FlxGraphic> return AssetCache.graphics = v;
	static inline function get_currentTrackedSounds():Map<String, Sound> return AssetCache.sounds;
	static inline function set_currentTrackedSounds(v:Map<String, Sound>):Map<String, Sound> return AssetCache.sounds = v;

	public static inline function excludeAsset(key:String)
		AssetCache.exclude(key);

	public static inline function clearUnusedMemory()
		AssetCache.clearUnused();

	public static inline function clearStoredMemory()
	{
		AssetCache.clearStored();
		clearPathCache();
	}

	public static inline function freeGraphicsFromMemory()
		AssetCache.freeGraphics();

	static public var currentLevel:String;

	static public function setCurrentLevel(name:String)
		currentLevel = name != null ? name.toLowerCase() : null;

	public static function getPath(file:String, ?type:AssetType = TEXT, ?parentfolder:String, ?modsAllowed:Bool = true):String
	{
		if (file == null) return null;
		if (!cachePaths) return resolvePath(file, type, parentfolder, modsAllowed);

		var cacheKey:String = '$file|$type|$parentfolder|$modsAllowed|$currentLevel' #if MODS_ALLOWED + '|' + Mods.currentModDirectory #end;
		lockCache();
		var cached:String = pathCache.get(cacheKey);
		unlockCache();
		if (cached != null) return cached;

		var resolved:String = resolvePath(file, type, parentfolder, modsAllowed);
		if (resolved != null)
		{
			lockCache();
			pathCache.set(cacheKey, resolved);
			unlockCache();
		}
		return resolved;
	}

	static function resolvePath(file:String, type:AssetType, parentfolder:String, modsAllowed:Bool):String
	{
		var alias:Null<String> = AssetAliases.get(file);

		#if MODS_ALLOWED
		if (modsAllowed)
		{
			var modded:String = modFolders(parentfolder != null ? '$parentfolder/$file' : file);
			if (FileSystem.exists(modded)) return modded;
			if (alias != null && parentfolder == null)
			{
				var moddedAlias:String = modFolders(alias);
				if (FileSystem.exists(moddedAlias)) return moddedAlias;
			}
		}
		#end

		if (parentfolder != null)
		{
			var folderPath:String = getFolderPath(file, parentfolder);
			if (alias != null && !assetExists(folderPath, type))
			{
				var aliasPath:String = getFolderPath(alias, parentfolder);
				if (assetExists(aliasPath, type)) return aliasPath;
			}
			return folderPath;
		}

		var folders:Array<String> = [];
		if (currentLevel != null && currentLevel != SHARED_FOLDER && currentLevel != PRELOAD_FOLDER) folders.push(currentLevel);
		folders.push(SHARED_FOLDER);
		folders.push(PRELOAD_FOLDER);

		for (folder in folders)
		{
			var path:String = getFolderPath(file, folder);
			if (assetExists(path, type)) return path;
			if (alias != null)
			{
				var aliasPath:String = getFolderPath(alias, folder);
				if (assetExists(aliasPath, type)) return aliasPath;
			}
		}
		return getSharedPath(file);
	}

	inline public static function getPreloadPath(file:String = '')
		return 'assets/$PRELOAD_FOLDER/$file';

	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, true);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, true);

	inline static public function json(key:String, ?folder:String)
		return getPath('data/$key.json', TEXT, folder, true);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, true);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, true);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, true);

	inline static public function hscript(key:String, ?folder:String)
		return getPath('$key.hx', TEXT, folder, true);

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if (FileSystem.exists(file)) return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline static public function sound(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('sounds/$key', modsAllowed);

	inline static public function music(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('music/$key', modsAllowed);

	inline static public function inst(song:String, ?modsAllowed:Bool = true):Sound
		return returnSound('${formatToSongPath(song)}/Inst', 'songs', modsAllowed);

	inline static public function voices(song:String, postfix:String = null, ?modsAllowed:Bool = true):Sound
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		if (postfix != null) songKey += '-' + postfix;
		return returnSound(songKey, 'songs', modsAllowed, false);
	}

	public static function vocalCandidates(?character:String, ?vocalsFile:String, ?fallback:String):Array<String>
	{
		var list:Array<String> = [];
		function push(value:String)
			if (value != null && value.length > 0 && !list.contains(value)) list.push(value);
		push(vocalsFile);
		if (character != null)
		{
			var parts:Array<String> = character.split('-');
			while (parts.length > 0)
			{
				push(parts.join('-'));
				parts.pop();
			}
		}
		push(fallback);
		return list;
	}

	public static function variationInst(song:String, ?variation:String, ?modsAllowed:Bool = true):Sound
	{
		if (variation != null && variation.length > 0)
		{
			var sound:Sound = returnSound('${formatToSongPath(song)}/Inst-$variation', 'songs', modsAllowed, false);
			if (sound != null) return sound;
		}
		return inst(song, modsAllowed);
	}

	public static function characterVoices(song:String, ?character:String, ?vocalsFile:String, ?fallback:String, allowPlain:Bool = true, ?modsAllowed:Bool = true, ?variation:String):Sound
	{
		if (variation != null && variation.length > 0)
		{
			for (postfix in vocalCandidates(character, vocalsFile, fallback))
			{
				var sound:Sound = voices(song, '$postfix-$variation', modsAllowed);
				if (sound != null) return sound;
			}
			var plain:Sound = voices(song, variation, modsAllowed);
			if (plain != null) return plain;
		}
		for (postfix in vocalCandidates(character, vocalsFile, fallback))
		{
			var sound:Sound = voices(song, postfix, modsAllowed);
			if (sound != null) return sound;
		}
		return allowPlain ? voices(song, null, modsAllowed) : null;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		var baseKey:String = key;
		key = Language.getFileTranslation('images/$key') + '.$IMAGE_EXT';
		var cached:FlxGraphic = AssetCache.getGraphic(key);
		if (cached != null) return cached;
		#if GIF_ALLOWED
		if (funkin.graphics.GifLoader.onlyGif(baseKey, parentFolder)) return funkin.graphics.GifLoader.firstFrame(baseKey, parentFolder, allowGPU);
		#end
		return cacheBitmap(key, parentFolder, null, allowGPU);
	}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String = getPath(key, IMAGE, parentFolder, true);
			if (isMissing(file)) return null;
			bitmap = loadBitmap(file);
			if (bitmap == null && key.endsWith('.$IMAGE_EXT'))
			{
				var base:String = key.substr(0, key.length - IMAGE_EXT.length);
				for (ext in IMAGE_FALLBACK_EXTS)
				{
					bitmap = loadBitmap(getPath(base + ext, IMAGE, parentFolder, true));
					if (bitmap != null) break;
				}
			}
			if (bitmap == null)
			{
				markMissing(file);
				FlxG.log.warn('Bitmap not found: $file | key: $key');
				return null;
			}
		}

		if (allowGPU && Save.data.cacheOnGPU && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}

		return AssetCache.addGraphic(key, FlxGraphic.fromBitmapData(bitmap, false, key));
	}

	public static function loadBitmap(file:String):BitmapData
	{
		if (file == null) return null;
		try
		{
			if (!isPolymodReplaced(file))
			{
				#if sys
				if (FileSystem.exists(file)) return BitmapData.fromFile(file);
				#end
			}
			if (OpenFlAssets.exists(file, IMAGE)) return OpenFlAssets.getBitmapData(file, false);
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function loadSound(file:String):Sound
	{
		if (file == null) return null;
		try
		{
			if (!isPolymodReplaced(file))
			{
				#if sys
				if (FileSystem.exists(file)) return Sound.fromFile(file);
				#end
			}
			if (OpenFlAssets.exists(file, SOUND)) return OpenFlAssets.getSound(file, false);
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function getContent(path:String):String
	{
		if (path == null) return null;
		try
		{
			if (!isPolymodReplaced(path))
			{
				#if sys
				if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return File.getContent(path);
				#end
			}
			if (OpenFlAssets.exists(path, TEXT)) return OpenFlAssets.getText(path);
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function getBytes(path:String):Bytes
	{
		if (path == null) return null;
		try
		{
			if (!isPolymodReplaced(path))
			{
				#if sys
				if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return File.getBytes(path);
				#end
			}
			if (OpenFlAssets.exists(path, BINARY)) return lime.utils.Assets.getBytes(path);
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function exists(path:String, ?type:AssetType):Bool
	{
		if (path == null) return false;
		#if sys
		if (FileSystem.exists(path)) return true;
		#end
		return assetExists(path, type);
	}

	static inline function assetExists(path:String, ?type:AssetType):Bool
		return type != null ? OpenFlAssets.exists(path, type) : OpenFlAssets.exists(path);

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
		return getContent(getPath(key, TEXT, null, !ignoreMods));

	public static function parseJson(key:String, ?folder:String):Dynamic
	{
		var path:String = json(key, folder);
		var raw:String = getContent(path);
		if (raw == null || raw.trim().length == 0) return null;
		try
		{
			return tjson.TJSON.parse(raw, path);
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Invalid JSON: $e');
			return null;
		}
	}

	public static function extension(path:String):String
	{
		if (path == null) return '';
		var dot:Int = path.lastIndexOf('.');
		var slash:Int = path.lastIndexOf('/');
		return dot > slash ? path.substr(dot + 1).toLowerCase() : '';
	}

	public static function withoutExtension(path:String):String
	{
		if (path == null) return null;
		var dot:Int = path.lastIndexOf('.');
		return dot > path.lastIndexOf('/') ? path.substr(0, dot) : path;
	}

	public static function readDirectory(folder:String, ?extension:String, ?modsAllowed:Bool = true):Array<String>
	{
		if (!folder.endsWith('/')) folder += '/';
		var found:Array<String> = [];
		function add(name:String)
		{
			if (extension != null && !name.endsWith(extension)) return;
			if (!found.contains(name)) found.push(name);
		}

		var bases:Array<String> = [];
		if (currentLevel != null && currentLevel != SHARED_FOLDER && currentLevel != PRELOAD_FOLDER) bases.push(getFolderPath(folder, currentLevel));
		bases.push(getSharedPath(folder));
		bases.push(getPreloadPath(folder));
		var assets:Array<String> = OpenFlAssets.list();
		for (base in bases)
		{
			#if sys
			if (FileSystem.exists(base) && FileSystem.isDirectory(base))
				for (file in FileSystem.readDirectory(base)) add(file);
			#end
			for (asset in assets)
				if (asset.startsWith(base))
				{
					var rest:String = asset.substr(base.length);
					if (rest.indexOf('/') == -1) add(rest);
				}
		}

		#if MODS_ALLOWED
		if (modsAllowed)
			for (dir in Mods.directoriesWithFile(getSharedPath(), folder))
				if (FileSystem.isDirectory(dir))
					for (file in FileSystem.readDirectory(dir)) add(file);
		#end
		return found;
	}

	inline static public function font(key:String)
	{
		var folderKey:String = Language.getFileTranslation('fonts/$key');
		#if MODS_ALLOWED
		var file:String = modFolders(folderKey);
		if (FileSystem.exists(file)) return file;
		#end
		return 'assets/$folderKey';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?parentFolder:String = null)
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			var modKey:String = key;
			if (parentFolder == 'songs') modKey = 'songs/$key';

			for (mod in Mods.getGlobalMods())
				if (resolveModPath(mods('$mod/$modKey')) != null)
					return true;

			if (resolveModPath(mods(Mods.currentModDirectory + '/' + modKey)) != null || resolveModPath(mods(modKey)) != null)
				return true;
		}
		#end
		return exists(getPath(key, type, parentFolder, false), type);
	}

	#if GIF_ALLOWED
	static public function gif(key:String, ?parentFolder:String = null):gifsupport.Gif
		return funkin.graphics.GifLoader.load(key, parentFolder);

	static public function getGifAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
		return funkin.graphics.GifLoader.frames(key, parentFolder, allowGPU);
	#end

	static function atlasData(key:String, extension:String, ?parentFolder:String):String
		return getContent(getPath(Language.getFileTranslation('images/$key') + extension, TEXT, parentFolder, true));

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		#if GIF_ALLOWED
		if (funkin.graphics.GifLoader.onlyGif(key, parentFolder)) return funkin.graphics.GifLoader.frames(key, parentFolder, allowGPU);
		#end
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null) return null;

		var xml:String = atlasData(key, '.xml', parentFolder);
		if (xml != null) return FlxAtlasFrames.fromSparrow(imageLoaded, xml);

		var json:String = atlasData(key, '.json', parentFolder);
		if (json != null) return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, json);

		var txt:String = atlasData(key, '.txt', parentFolder);
		if (txt != null) return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, txt);

		FlxG.log.warn('Atlas data not found for: $key');
		return null;
	}

	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var parentFrames:FlxAtlasFrames = getAtlas(keys[0].trim(), parentFolder, allowGPU);
		if (parentFrames != null && keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if (extraFrames != null)
					parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	static public function getSparrowAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		var xml:String = atlasData(key, '.xml', parentFolder);
		if (imageLoaded == null || xml == null)
		{
			FlxG.log.warn('Sparrow atlas not found: $key');
			return null;
		}
		return FlxAtlasFrames.fromSparrow(imageLoaded, xml);
	}

	static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		var txt:String = atlasData(key, '.txt', parentFolder);
		if (imageLoaded == null || txt == null)
		{
			FlxG.log.warn('Packer atlas not found: $key');
			return null;
		}
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, txt);
	}

	static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		var json:String = atlasData(key, '.json', parentFolder);
		if (imageLoaded == null || json == null)
		{
			FlxG.log.warn('Aseprite atlas not found: $key');
			return null;
		}
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, json);
	}

	static public function formatToSongPath(path:String):String
	{
		if (path == null) return '';
		var invalidChars:EReg = ~/[~&;:<>#\s]/g;
		var hideChars:EReg = ~/[.,'"%?!]/g;
		return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
	}

	public static function returnSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true):Sound
	{
		var translated:String = Language.getFileTranslation(key);
		var file:String = getPath('$translated.$SOUND_EXT', SOUND, path, modsAllowed);
		var cached:Sound = AssetCache.getSound(file);
		if (cached != null) return cached;

		var sound:Sound = isMissing(file) ? null : loadSound(file);
		if (sound == null)
		{
			for (ext in SOUND_FALLBACK_EXTS)
			{
				if (ext == SOUND_EXT) continue;
				var alternate:String = getPath('$translated.$ext', SOUND, path, modsAllowed);
				var alternateCached:Sound = AssetCache.getSound(alternate);
				if (alternateCached != null) return alternateCached;
				if (isMissing(alternate)) continue;
				var loaded:Sound = loadSound(alternate);
				if (loaded != null) return AssetCache.addSound(alternate, loaded);
				markMissing(alternate);
			}
			markMissing(file);
		}
		if (sound == null)
		{
			if (!beepOnNull) return null;
			FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
			return FlxAssets.getSound('flixel/sounds/beep');
		}
		return AssetCache.addSound(file, sound);
	}

	public static function isPolymodReplaced(path:String):Bool
	{
		#if POLYMOD_ALLOWED
		if (path == null || !path.startsWith('assets/')) return false;
		var library = @:privateAccess polymod.Polymod.assetLibrary;
		return library != null && library.check(path);
		#else
		return false;
		#end
	}

	#if MODS_ALLOWED
	#if mobile
	static var _modsRoot:String = null;

	public static function resetModsRoot()
		_modsRoot = null;
	#end

	static public function mods(key:String = '')
	{
		#if mobile
		if (_modsRoot == null) _modsRoot = haxe.io.Path.addTrailingSlash(Sys.getCwd()) + 'mods/';
		return _modsRoot + key;
		#else
		return 'mods/' + key;
		#end
	}

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.' + IMAGE_EXT);

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');

	static public function modFolders(key:String)
	{
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = resolveModPath(mods(Mods.currentModDirectory + '/' + key));
			if (fileToCheck != null)
				return fileToCheck;
		}

		for (mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = resolveModPath(mods(mod + '/' + key));
			if (fileToCheck != null)
				return fileToCheck;
		}

		var rootFile:String = resolveModPath(mods(key));
		if (rootFile != null) return rootFile;

		var alias:Null<String> = AssetAliases.folderAlias(key);
		if (alias != null)
		{
			var aliased:String = findModFile(alias);
			if (aliased != null) return aliased;
		}
		return mods(key);
	}

	static function findModFile(key:String):String
	{
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = resolveModPath(mods(Mods.currentModDirectory + '/' + key));
			if (fileToCheck != null) return fileToCheck;
		}
		for (mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = resolveModPath(mods(mod + '/' + key));
			if (fileToCheck != null) return fileToCheck;
		}
		return resolveModPath(mods(key));
	}

	#if mobile
	static var _dirCache:Map<String, Array<String>> = new Map();
	static var _dirMutex:sys.thread.Mutex = new sys.thread.Mutex();

	public static function clearModPathCache()
	{
		_dirMutex.acquire();
		_dirCache.clear();
		_dirMutex.release();
	}

	static function listDirectory(dir:String):Array<String>
	{
		_dirMutex.acquire();
		var entries:Array<String> = _dirCache.get(dir);
		_dirMutex.release();
		if (entries != null) return entries;

		try
		{
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return null;
			entries = FileSystem.readDirectory(dir);
		}
		catch (e:Dynamic)
		{
			return null;
		}

		_dirMutex.acquire();
		_dirCache.set(dir, entries);
		_dirMutex.release();
		return entries;
	}
	#end

	public static function resolveModPath(path:String):String
	{
		if (FileSystem.exists(path)) return path;
		#if mobile
		var root:String = mods();
		if (!path.startsWith(root)) return null;

		var current:String = root.substr(0, root.length - 1);
		for (part in path.substr(root.length).split('/'))
		{
			if (part.length == 0) continue;
			var entries:Array<String> = listDirectory(current);
			if (entries == null) return null;

			var lower:String = part.toLowerCase();
			var match:String = null;
			for (entry in entries)
			{
				if (entry.toLowerCase() == lower)
				{
					match = entry;
					break;
				}
			}
			if (match == null) return null;
			current += '/' + match;
		}
		return path.endsWith('/') ? current + '/' : current;
		#else
		return null;
		#end
	}
	#end

	#if flxanimate
	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		var changedAnimJson:Bool = false;
		var changedAtlasJson:Bool = false;
		var changedImage:Bool = false;

		if (spriteJson != null)
		{
			changedAtlasJson = true;
			spriteJson = getContent(spriteJson);
		}

		if (animationJson != null)
		{
			changedAnimJson = true;
			animationJson = getContent(animationJson);
		}

		if (Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = folderOrImg;
			if (!changedAnimJson)
			{
				changedAnimJson = true;
				animationJson = getTextFromFile('images/$originalPath/Animation.json');
			}

			if (!changedAtlasJson)
			{
				var images:Array<FlxGraphic> = [];
				var maps:Array<String> = [];
				for (i in 0...64)
				{
					var st:String = i == 0 ? '' : '$i';
					var map:String = getTextFromFile('images/$originalPath/spritemap$st.json');
					if (map == null)
					{
						if (i > 1) break;
						continue;
					}
					var graphic:FlxGraphic = image('$originalPath/spritemap$st');
					if (graphic == null) continue;
					images.push(graphic);
					maps.push(map);
					if (i == 0) break;
				}
				if (images.length > 0)
				{
					spr.loadSpritemaps(images, maps, animationJson);
					return;
				}
			}

			for (i in 0...10)
			{
				var st:String = i == 0 ? '' : '$i';
				if (fileExists('images/$originalPath/spritemap$st.png', IMAGE))
				{
					changedImage = true;
					folderOrImg = image('$originalPath/spritemap$st');
					break;
				}
			}

			if (!changedImage)
			{
				changedImage = true;
				folderOrImg = image(originalPath);
			}
		}

		spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
	}
	#end
}
